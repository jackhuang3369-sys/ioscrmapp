import Foundation
@preconcurrency import Tabby
import os

private let tabbyLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "ioscrmapp",
    category: "Tabby"
)

// MARK: - Protocol

protocol TabbyServicing: Sendable {
    /// Whether checkout requires the real Tabby SDK sheet (true) or can be simulated (false for mock/testing).
    /// Mock mode skips the SDK sheet because TabbySDK.shared.session is never configured,
    /// which would otherwise result in a blank checkout page.
    var requiresSDKCheckout: Bool { get }

    /// Initialize the Tabby SDK (Phase 1: client-side API key; Phase 2: no-op, backend owns session creation)
    func setup(apiKey: String) async

    /// Phase 1: SDK creates session internally; Phase 2: backend returns session, this method only stores it
    func prepareCheckout(amount: Decimal, session: CustSubInfo, lang: Lang) async throws -> TabbySessionPayload

    /// Launch the Tabby checkout sheet with an existing session.
    /// On completion, the caller must invoke handleCheckoutResult to finalize or clean up.
    func presentCheckout(sessionId: String, paymentId: String, amount: Decimal, currency: Currency) async throws

    /// Process the Tabby SDK checkout result and clear internal state.
    /// Returns the outcome for the caller to decide UI flow; the service handles cleanup internally.
    func handleCheckoutResult(_ result: TabbyResult) -> TabbyCheckoutOutcome

    /// Reset all in-flight checkout state (called on user cancel, error, or checkout completion)
    func resetCheckout() async
}

// MARK: - Error

enum TabbyServiceError: Error {
    case sessionCreationFailed(String)
    case checkoutCancelled
    case checkoutFailed(String)
    case checkoutExpired
    case sdkNotInitialized

    var textValue: LocalizedTextValue {
        switch self {
        case .sessionCreationFailed(let message):
            return .literal(message)
        case .checkoutCancelled:
            return .literal("")
        case .checkoutFailed(let message):
            return .literal(message)
        case .checkoutExpired:
            return .literal("Tabby session expired. Please try again.")
        case .sdkNotInitialized:
            return .literal("Tabby SDK not initialized.")
        }
    }
}

// MARK: - Session Payload

struct TabbySessionPayload: Sendable, Equatable {
    let sessionId: String
    let paymentId: String
    let amount: Decimal
    let currency: Currency
    let merchantCode: String
    let createdAt: Date
}

// MARK: - Mock Service

struct MockTabbyService: TabbyServicing {
    // Mock mode does not configure the real Tabby SDK — skip presenting the SDK checkout sheet
    let requiresSDKCheckout = false

    private let sessionHolder = TabbySessionHolder()
    private let stateHolder = MockStateHolder()

    func setup(apiKey: String) async {
        stateHolder.setInitialized()
        tabbyLogger.info("MockTabbyService initialized")
    }

    /// Phase 1 mock: simulates backend session creation with a delay
    func prepareCheckout(
        amount: Decimal,
        session: CustSubInfo,
        lang: Lang
    ) async throws -> TabbySessionPayload {
        guard stateHolder.isInitialized else {
            throw TabbyServiceError.sdkNotInitialized
        }

        try await Task.sleep(nanoseconds: 500_000_000)

        let payload = TabbySessionPayload(
            sessionId: "mock-session-\(UUID().uuidString.prefix(8))",
            paymentId: "mock-payment-\(UUID().uuidString.prefix(8))",
            amount: amount,
            currency: .AED,
            merchantCode: "ae",
            createdAt: Date()
        )

        sessionHolder.store(payload)
        return payload
    }

    /// Phase 1 mock: no-op; in Phase 2 this will configure the SDK with backend-returned session
    func presentCheckout(
        sessionId: String,
        paymentId: String,
        amount: Decimal,
        currency: Currency
    ) async throws {
        guard stateHolder.isInitialized else {
            throw TabbyServiceError.sdkNotInitialized
        }
        tabbyLogger.info("MockTabbyService: presentCheckout for session \(sessionId)")
    }

    func handleCheckoutResult(_ result: TabbyResult) -> TabbyCheckoutOutcome {
        TabbyCheckoutOutcome(from: result, session: sessionHolder.current)
    }

    func resetCheckout() async {
        sessionHolder.clear()
    }

    // MARK: - Thread-safe helpers (shared pattern with RemoteTabbyService)

    private final class TabbySessionHolder: @unchecked Sendable {
        private var _session: TabbySessionPayload?
        private let lock = NSLock()

        var current: TabbySessionPayload? {
            lock.lock()
            defer { lock.unlock() }
            return _session
        }

        func store(_ session: TabbySessionPayload) {
            lock.lock()
            _session = session
            lock.unlock()
        }

        func clear() {
            lock.lock()
            _session = nil
            lock.unlock()
        }
    }

    private final class MockStateHolder: @unchecked Sendable {
        private var _isInitialized = false
        private let lock = NSLock()

        var isInitialized: Bool {
            lock.lock()
            defer { lock.unlock() }
            return _isInitialized
        }

        func setInitialized() {
            lock.lock()
            _isInitialized = true
            lock.unlock()
        }
    }
}

// MARK: - Remote Service

struct RemoteTabbyService: TabbyServicing {
    // Remote mode uses the real Tabby SDK checkout sheet
    let requiresSDKCheckout = true

    /// Held across the prepare → present → handle lifecycle so handleCheckoutResult can map the outcome
    private let sessionHolder = TabbySessionHolder()

    func setup(apiKey: String) async {
        await MainActor.run {
            TabbySDK.shared.setup(withApiKey: apiKey)
        }
        tabbyLogger.info("TabbySDK initialized")
    }

    /// Phase 1: SDK creates the session; Phase 2: replace with backend API call
    func prepareCheckout(
        amount: Decimal,
        session: CustSubInfo,
        lang: Lang
    ) async throws -> TabbySessionPayload {
        let payload = buildCheckoutPayload(amount: amount, session: session, lang: lang)

        tabbyLogger.info("Creating Tabby session for amount: \(amount)")

        return try await withCheckedThrowingContinuation { continuation in
            TabbySDK.shared.configure(forPayment: payload) { result in
                switch result {
                case .success(let sessionPayload):
                    tabbyLogger.info("Tabby session created: \(sessionPayload.sessionId), products: \(sessionPayload.tabbyProductTypes)")

                    if !sessionPayload.tabbyProductTypes.contains(.installments) {
                        tabbyLogger.warning("Tabby rejected: no installments available, reason: \(sessionPayload.rejectionReason?.rawValue ?? "unknown")")
                        continuation.resume(throwing: TabbyServiceError.sessionCreationFailed(
                            "Tabby payment not available for this transaction. Please try a different payment method."
                        ))
                        return
                    }

                    let tabbyPayload = TabbySessionPayload(
                        sessionId: sessionPayload.sessionId,
                        paymentId: sessionPayload.paymentId,
                        amount: amount,
                        currency: .AED,
                        merchantCode: "ae",
                        createdAt: Date()
                    )
                    continuation.resume(returning: tabbyPayload)

                case .failure(let error):
                    tabbyLogger.error("Tabby session creation failed: \(error.localizedDescription)")
                    continuation.resume(throwing: TabbyServiceError.sessionCreationFailed(
                        "Failed to initialize Tabby checkout. Please try again."
                    ))
                }
            }
        }
    }

    /// Phase 1: no-op (SDK already has the session from prepareCheckout); Phase 2: pass backend session to SDK
    func presentCheckout(
        sessionId: String,
        paymentId: String,
        amount: Decimal,
        currency: Currency
    ) async throws {
        // Store for handleCheckoutResult to resolve the outcome
        sessionHolder.store(TabbySessionPayload(
            sessionId: sessionId,
            paymentId: paymentId,
            amount: amount,
            currency: currency,
            merchantCode: "ae",
            createdAt: Date()
        ))
        tabbyLogger.info("Tabby session stored for checkout: \(sessionId)")
    }

    func handleCheckoutResult(_ result: TabbyResult) -> TabbyCheckoutOutcome {
        TabbyCheckoutOutcome(from: result, session: sessionHolder.current)
    }

    func resetCheckout() async {
        sessionHolder.clear()
    }

    // MARK: - Private

    /// Thread-safe holder for the active Tabby session across the checkout lifecycle
    private final class TabbySessionHolder: @unchecked Sendable {
        private var _session: TabbySessionPayload?
        private let lock = NSLock()

        var current: TabbySessionPayload? {
            lock.lock()
            defer { lock.unlock() }
            return _session
        }

        func store(_ session: TabbySessionPayload) {
            lock.lock()
            _session = session
            lock.unlock()
        }

        func clear() {
            lock.lock()
            _session = nil
            lock.unlock()
        }
    }

    private func buildCheckoutPayload(
        amount: Decimal,
        session: CustSubInfo,
        lang: Lang
    ) -> TabbyCheckoutPayload {
        let email = session.displayName.isEmpty
            ? "user@du.ae"
            : "\(session.phoneNumber.replacingOccurrences(of: " ", with: ""))@du.ae"

        let buyer = Buyer(
            email: email,
            phone: session.phoneNumber.replacingOccurrences(of: " ", with: ""),
            name: session.displayName.isEmpty ? "Prepaid User" : session.displayName,
            dob: nil
        )

        let orderItem = OrderItem(
            description: "Mobile prepaid recharge",
            product_url: nil,
            quantity: 1,
            reference_id: "recharge_\(UUID().uuidString.prefix(8))",
            title: "Mobile Recharge",
            unit_price: NSDecimalNumber(decimal: amount).stringValue,
            category: "Recharge"
        )

        let order = Order(
            reference_id: "recharge_\(UUID().uuidString.prefix(12))",
            items: [orderItem],
            shipping_amount: "0",
            tax_amount: "0"
        )

        let shippingAddress = ShippingAddress(
            address: "N/A",
            city: "Dubai",
            zip: "00000"
        )

        let buyerHistory = BuyerHistory(
            registered_since: "2024-01-01T00:00:00Z",
            loyalty_level: 0
        )

        let payment = Payment(
            amount: NSDecimalNumber(decimal: amount).stringValue,
            currency: .AED,
            description: "du Mobile Recharge",
            buyer: buyer,
            buyer_history: buyerHistory,
            order: order,
            order_history: [],
            shipping_address: shippingAddress
        )

        return TabbyCheckoutPayload(merchant_code: "ae", lang: lang, payment: payment)
    }
}

// MARK: - Checkout Outcome

enum TabbyCheckoutOutcome: Sendable {
    case authorized(sessionId: String, paymentId: String)
    case rejected
    case cancelled
    case expired

    init(from tabbyResult: TabbyResult, session: TabbySessionPayload? = nil) {
        switch tabbyResult {
        case .authorized:
            self = .authorized(
                sessionId: session?.sessionId ?? "",
                paymentId: session?.paymentId ?? ""
            )
        case .rejected:
            self = .rejected
        case .close:
            self = .cancelled
        case .expired:
            self = .expired
        }
    }

    var error: TabbyServiceError? {
        switch self {
        case .authorized:
            return nil
        case .rejected:
            return .checkoutFailed("Tabby declined this transaction. Please try a different payment method.")
        case .cancelled:
            return .checkoutCancelled
        case .expired:
            return .checkoutExpired
        }
    }
}