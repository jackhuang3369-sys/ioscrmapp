import AuthenticationServices
import Foundation
import os

/// Drives UAE Pass OAuth for the eKYC onboarding step.
///
/// Option A: loginWithCode() saves tokens to Keychain, establishing the backend
/// session. sessionStore.signIn() is deliberately deferred to activation completion
/// so the app UI stays in the onboarding flow.
@MainActor
final class EKYCViewModel: ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var error: EKYCError?

    private let uaePassService: UAEPassServicing
    private var authSession: ASWebAuthenticationSession?
    private var contextProvider: EKYCPresentationContextProvider?

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "ioscrmapp",
        category: "EKYCFlow"
    )

    init(uaePassService: UAEPassServicing) {
        self.uaePassService = uaePassService
    }

    // MARK: - Public

    func startUAEPassVerification(onSuccess: @escaping (EKYCResult) -> Void) {
        guard !isLoading else { return }
        error = nil
        isLoading = true

        Task {
            do {
                let config = try await uaePassService.getConfig()
                let url = try buildAuthorizeURL(from: config)
                let code = try await presentAuthSession(url: url, callbackScheme: "duapp")

                // loginWithCode saves tokens to Keychain (Option A: implicit backend session)
                let customer = try await uaePassService.loginWithCode(
                    code: code,
                    state: config.state,
                    requestId: UUID().uuidString
                )

                let result = EKYCResult(
                    method: .uaepass,
                    identityID: customer.userID ?? customer.phoneNumber,
                    verifiedAt: Date(),
                    metadata: EKYCMetadata(
                        fullName: customer.displayName,
                        phoneNumber: customer.phoneNumber,
                        documentType: nil,
                        documentNumber: nil,
                        documentExpiryDate: nil
                    ),
                    enhancedResults: nil
                )

                logger.info("UAE Pass eKYC verification succeeded, identityID: \(result.identityID)")
                isLoading = false
                onSuccess(result)
            } catch let e as UAEPassAuthError where e == .userCancelled {
                // Silent cancel — user dismissed UAE Pass, no error shown
                logger.info("UAE Pass eKYC cancelled by user")
                isLoading = false
            } catch let e as UAEPassAuthError {
                logger.error("UAE Pass eKYC failed: \(e.localizedDescription)")
                isLoading = false
                error = .uaepassFailed(reason: e.localizedDescription)
            } catch {
                logger.error("UAE Pass eKYC unexpected error: \(error.localizedDescription)")
                isLoading = false
                self.error = .uaepassFailed(reason: error.localizedDescription)
            }
        }
    }

    /// Cancel an in-flight OAuth session (called when user navigates back).
    func cancel() {
        authSession?.cancel()
        authSession = nil
        contextProvider = nil
        isLoading = false
    }

    func clearError() {
        error = nil
    }

    // MARK: - Private

    private func buildAuthorizeURL(from config: UAEPassConfig) throws -> URL {
        guard var components = URLComponents(string: config.authorizeURL) else {
            throw UAEPassAuthError.configFetchFailed
        }
        components.queryItems = [
            URLQueryItem(name: "client_id",    value: config.clientId),
            URLQueryItem(name: "redirect_uri", value: config.redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope",        value: config.scope),
            URLQueryItem(name: "state",        value: config.state),
            URLQueryItem(name: "acr_values",   value: config.installedFlowAcrValues),
            URLQueryItem(name: "language",     value: config.language),
        ]
        guard let url = components.url else {
            throw UAEPassAuthError.configFetchFailed
        }
        return url
    }

    private func presentAuthSession(url: URL, callbackScheme: String) async throws -> String {
        contextProvider = EKYCPresentationContextProvider()

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { [weak self] callbackURL, error in
                self?.contextProvider = nil
                self?.authSession = nil

                if let error = error as? ASWebAuthenticationSessionError {
                    switch error.code {
                    case .canceledLogin:
                        continuation.resume(throwing: UAEPassAuthError.userCancelled)
                    default:
                        continuation.resume(throwing: UAEPassAuthError.authSessionFailed(error.localizedDescription))
                    }
                    return
                }

                guard
                    let callbackURL,
                    let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                    let codeItem = components.queryItems?.first(where: { $0.name == "code" }),
                    let code = codeItem.value,
                    !code.isEmpty
                else {
                    continuation.resume(throwing: UAEPassAuthError.noAuthCode)
                    return
                }

                continuation.resume(returning: code)
            }

            session.prefersEphemeralWebBrowserSession = true
            session.presentationContextProvider = contextProvider
            authSession = session
            session.start()
        }
    }
}

// MARK: - Presentation Context

private final class EKYCPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let window = scene.windows.first(where: { $0.isKeyWindow })
        else {
            return UIWindow()
        }
        return window
    }
}
