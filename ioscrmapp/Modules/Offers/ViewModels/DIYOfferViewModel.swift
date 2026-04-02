import Foundation
import SwiftUI

@MainActor
final class DIYOfferViewModel: ObservableObject {
    enum ScreenState {
        case idle
        case loading
        case loaded
        case failed(LocalizedTextValue)
    }

    @Published private(set) var screenState: ScreenState = .idle
    @Published private(set) var bootstrap: DIYOfferBootstrap?
    @Published private(set) var pricing: DIYOfferPricing?
    @Published private(set) var isPricingLoading = false
    @Published private(set) var switchNotice: LocalizedTextValue?
    @Published private(set) var bannerMessage: LocalizedTextValue?
    @Published var activePeriodID: String?
    @Published var valueInputs: [String: String] = [:]
    @Published var fieldErrors: [String: LocalizedTextValue] = [:]
    @Published var isConfirmSheetPresented = false
    @Published var isSubmitting = false
    @Published var successResult: OfferAcceptedResult?
    @Published var failureResult: DIYOfferFailureResult?

    private let session: CustSubInfo
    private let offersService: any OffersServicing
    private var hasLoaded = false
    private var pricingTask: Task<Void, Never>?

    init(session: CustSubInfo, offersService: any OffersServicing) {
        self.session = session
        self.offersService = offersService
    }

    deinit {
        pricingTask?.cancel()
    }

    var serviceNumberText: String {
        AuthValidator.localPhoneDigits(session.serviceNumber ?? session.phoneNumber)
    }

    var activePeriod: DIYOfferPeriod? {
        guard let bootstrap else {
            return nil
        }
        return bootstrap.periods.first(where: { $0.id == activePeriodID })
    }

    var allPeriods: [DIYOfferPeriod] {
        bootstrap?.periods ?? []
    }

    var activeResources: [DIYOfferResource] {
        activePeriod?.resources ?? []
    }

    var hasAnyConfigurableResources: Bool {
        allPeriods.contains { !$0.resources.isEmpty }
    }

    var isEmptyState: Bool {
        !hasAnyConfigurableResources
    }

    var totalDisplayText: String {
        pricing?.totalDisplayText ?? defaultZeroDisplayText
    }

    var canSubmit: Bool {
        guard !activeResources.isEmpty, fieldErrors.isEmpty, pricing != nil, !isPricingLoading else {
            return false
        }
        return selectedResources.count == activeResources.count
    }

    var confirmSummaryRows: [(String, String)] {
        [
            ("offers.diy.confirm.period", activePeriod?.title ?? "-"),
            ("offers.diy.confirm.effective", "offers.effective.immediate"),
            ("offers.diy.confirm.total", totalDisplayText),
        ]
    }

    func loadIfNeeded() async {
        guard !hasLoaded else {
            return
        }
        await reload()
    }

    func reload() async {
        screenState = .loading
        bannerMessage = nil
        switchNotice = nil
        do {
            let bootstrap = try await offersService.fetchDIYBootstrap(session: session)
            self.bootstrap = bootstrap
            hasLoaded = true
            screenState = .loaded
            applyInitialPeriod(using: bootstrap)
        } catch {
            screenState = .failed((error as? OffersServiceError)?.textValue ?? .key("offers.state.errorSubtitle"))
        }
    }

    func selectPeriod(_ period: DIYOfferPeriod) {
        switchNotice = nil
        activePeriodID = period.id
        resetInputs(for: period)
        schedulePricingRefresh()
    }

    func inputText(for resource: DIYOfferResource) -> String {
        valueInputs[resource.id] ?? "\(resource.defaultValue)"
    }

    func numericValue(for resource: DIYOfferResource) -> Int {
        Int(inputText(for: resource)) ?? resource.defaultValue
    }

    func updateValue(_ rawValue: String, for resource: DIYOfferResource) {
        let sanitized = rawValue.filter(\.isNumber)
        valueInputs[resource.id] = sanitized
        if let message = validationMessage(for: resource, rawValue: sanitized) {
            fieldErrors[resource.id] = message
        } else {
            fieldErrors.removeValue(forKey: resource.id)
        }
        schedulePricingRefresh()
    }

    func validationMessage(for resource: DIYOfferResource) -> LocalizedTextValue? {
        validationMessage(for: resource, rawValue: inputText(for: resource))
    }

    func openConfirmation() {
        guard canSubmit else {
            return
        }
        bannerMessage = nil
        isConfirmSheetPresented = true
    }

    func dismissBanner() {
        bannerMessage = nil
    }

    func dismissSuccessResult() {
        successResult = nil
    }

    func dismissFailureResult() {
        failureResult = nil
    }

    func submit() async {
        guard let request = submissionRequest else {
            return
        }

        isSubmitting = true
        do {
            let result = try await offersService.submitDIYOffer(request, session: session)
            isSubmitting = false
            isConfirmSheetPresented = false
            successResult = result
        } catch let error as DIYOfferSubmissionError {
            isSubmitting = false
            isConfirmSheetPresented = false
            switch error {
            case let .quotationRejected(message):
                bannerMessage = message
            case let .submissionFailed(result):
                failureResult = result
            }
        } catch {
            isSubmitting = false
            isConfirmSheetPresented = false
            bannerMessage = (error as? OffersServiceError)?.textValue ?? .key("offers.failure.body")
        }
    }

    private var defaultZeroDisplayText: String {
        "\(pricing?.totalAmount ?? "0") \(bootstrap?.currencyName ?? "SDG")"
    }

    private var selectedResources: [DIYOfferSelectedResource] {
        activeResources.compactMap { resource in
            guard let value = Int(inputText(for: resource)) else {
                return nil
            }
            return DIYOfferSelectedResource(resource: resource, value: value)
        }
    }

    private var submissionRequest: DIYOfferSubmissionRequest? {
        guard let period = activePeriod, let pricing else {
            return nil
        }
        let resources = selectedResources
        guard resources.count == activeResources.count else {
            return nil
        }
        return DIYOfferSubmissionRequest(period: period, resources: resources, pricing: pricing)
    }

    private func validationMessage(for resource: DIYOfferResource, rawValue: String) -> LocalizedTextValue? {
        guard !rawValue.isEmpty, let value = Int(rawValue), value >= resource.minValue, value <= resource.maxValue else {
            return .key(
                "offers.diy.validation.range",
                arguments: ["\(resource.minValue)", "\(resource.maxValue)"]
            )
        }
        return nil
    }

    private func applyInitialPeriod(using bootstrap: DIYOfferBootstrap) {
        guard let firstPeriod = bootstrap.periods.first else {
            activePeriodID = nil
            valueInputs = [:]
            fieldErrors = [:]
            pricing = nil
            return
        }

        if !firstPeriod.resources.isEmpty {
            activePeriodID = firstPeriod.id
            resetInputs(for: firstPeriod)
            schedulePricingRefresh()
            return
        }

        if let fallback = bootstrap.periods.first(where: { !$0.resources.isEmpty }) {
            activePeriodID = fallback.id
            resetInputs(for: fallback)
            switchNotice = .key(
                "offers.diy.switchNotice",
                arguments: [firstPeriod.title, fallback.title]
            )
            schedulePricingRefresh()
            return
        }

        activePeriodID = firstPeriod.id
        valueInputs = [:]
        fieldErrors = [:]
        pricing = nil
    }

    private func resetInputs(for period: DIYOfferPeriod) {
        valueInputs = period.resources.reduce(into: [:]) { partialResult, resource in
            partialResult[resource.id] = "\(resource.defaultValue)"
        }
        fieldErrors = [:]
    }

    private func schedulePricingRefresh() {
        pricingTask?.cancel()

        guard !isEmptyState, let period = activePeriod else {
            pricing = nil
            isPricingLoading = false
            return
        }

        let resources = selectedResources
        guard resources.count == period.resources.count, fieldErrors.isEmpty else {
            pricing = nil
            isPricingLoading = false
            return
        }

        isPricingLoading = true
        let currencyName = bootstrap?.currencyName ?? "SDG"
        pricingTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else {
                return
            }
            await self?.calculatePricing(period: period, resources: resources, currencyName: currencyName)
        }
    }

    private func calculatePricing(
        period: DIYOfferPeriod,
        resources: [DIYOfferSelectedResource],
        currencyName: String
    ) async {
        do {
            let pricing = try await offersService.calculateDIYPrice(
                DIYOfferPricingRequest(period: period, resources: resources, currencyName: currencyName),
                session: session
            )
            self.pricing = pricing
            self.isPricingLoading = false
        } catch {
            self.pricing = nil
            self.isPricingLoading = false
            self.bannerMessage = (error as? OffersServiceError)?.textValue ?? .key("offers.failure.body")
        }
    }
}
