import Foundation

@MainActor
final class NumberSelectionViewModel: ObservableObject {
    @Published var searchText = ""
    @Published private(set) var premiumNumbers: [NumberInventoryItem] = []
    @Published private(set) var standardNumbers: [NumberInventoryItem] = []
    @Published private(set) var isLoadingInitial = false
    @Published private(set) var loadingCategories: Set<NumberCategory> = []
    @Published private(set) var selectedNumber: NumberInventoryItem?
    @Published private(set) var selectedMsisdn: String?
    @Published private(set) var reservingMsisdn: String?
    @Published var errorMessage: String?

    private let service: NumberInventoryServicing
    private let onboardingStateStore: OnboardingStateStore
    private var nextPageByCategory: [NumberCategory: Int?] = [:]
    private var searchTask: Task<Void, Never>?
    private let pageSize = 4

    init(
        service: NumberInventoryServicing = MockNumberInventoryService(),
        onboardingStateStore: OnboardingStateStore = OnboardingStateStore()
    ) {
        self.service = service
        self.onboardingStateStore = onboardingStateStore
        NumberCategory.allCases.forEach { nextPageByCategory[$0] = 0 }
    }

    deinit {
        searchTask?.cancel()
    }

    func loadInitialIfNeeded() {
        guard premiumNumbers.isEmpty && standardNumbers.isEmpty else { return }
        Task { await reload() }
    }

    func reload() async {
        isLoadingInitial = true
        errorMessage = nil
        selectedNumber = nil
        selectedMsisdn = nil
        NumberCategory.allCases.forEach { nextPageByCategory[$0] = 0 }

        await loadPage(for: .premium, reset: true)
        await loadPage(for: .standard, reset: true)

        isLoadingInitial = false
    }

    func updateSearchText(_ value: String) {
        searchText = value
        searchTask?.cancel()

        // Debounce suffix search so horizontal scrolling stays smooth while users type.
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await self?.reload()
        }
    }

    func loadMoreIfNeeded(for category: NumberCategory, currentItem: NumberInventoryItem) {
        let numbers = numbers(for: category)
        guard numbers.last?.id == currentItem.id else { return }
        Task { await loadPage(for: category, reset: false) }
    }

    func select(_ number: NumberInventoryItem) {
        guard number.reservationStatus == .available else {
            errorMessage = "This number is no longer available."
            return
        }

        selectedNumber = number
        // Keep a direct selected id for SwiftUI diffing so card styling updates immediately
        // even if the selected item object is replaced by a later inventory refresh.
        selectedMsisdn = number.msisdn
    }

    func reserveSelectedNumber() async -> NumberSelection? {
        guard let selectedNumber else { return nil }

        reservingMsisdn = selectedNumber.msisdn
        errorMessage = nil

        do {
            let selection = try await service.reserve(msisdn: selectedNumber.msisdn)
            onboardingStateStore.save(selection)
            reservingMsisdn = nil
            return selection
        } catch {
            reservingMsisdn = nil
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func loadPage(for category: NumberCategory, reset: Bool) async {
        guard let nextPage = nextPageByCategory[category] ?? 0 else { return }
        guard !loadingCategories.contains(category) else { return }

        loadingCategories.insert(category)
        defer { loadingCategories.remove(category) }

        do {
            let page = try await service.fetchNumbers(
                category: category,
                suffix: normalizedSearchSuffix,
                page: nextPage,
                pageSize: pageSize
            )

            if reset {
                setNumbers(page.items, for: category)
            } else {
                appendNumbers(page.items, for: category)
            }
            nextPageByCategory[category] = page.nextPage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var normalizedSearchSuffix: String? {
        let suffix = searchText.filter(\.isNumber)
        return suffix.isEmpty ? nil : suffix
    }

    private func numbers(for category: NumberCategory) -> [NumberInventoryItem] {
        switch category {
        case .premium:
            return premiumNumbers
        case .standard:
            return standardNumbers
        }
    }

    private func setNumbers(_ numbers: [NumberInventoryItem], for category: NumberCategory) {
        switch category {
        case .premium:
            premiumNumbers = numbers
        case .standard:
            standardNumbers = numbers
        }
    }

    private func appendNumbers(_ numbers: [NumberInventoryItem], for category: NumberCategory) {
        switch category {
        case .premium:
            premiumNumbers.append(contentsOf: numbers)
        case .standard:
            standardNumbers.append(contentsOf: numbers)
        }
    }
}
