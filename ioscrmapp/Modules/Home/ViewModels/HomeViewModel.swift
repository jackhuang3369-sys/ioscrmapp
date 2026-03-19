import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    enum ScreenState: Equatable {
        case idle
        case loading
        case loaded
        case failed(LocalizedTextValue)
    }

    @Published private(set) var screenState: ScreenState = .idle
    @Published private(set) var dashboard: HomeDashboardSnapshot?
    @Published private(set) var bannerMessage: LocalizedTextValue?

    private let session: CustSubInfo
    private let homeService: any HomeServicing
    private var hasLoaded = false
    private var inFlightLoadTask: Task<HomeDashboardSnapshot, Error>?

    init(session: CustSubInfo, homeService: any HomeServicing) {
        self.session = session
        self.homeService = homeService
    }

    func loadIfNeeded() async {
        guard !hasLoaded else {
            return
        }

        await load(showLoading: true, preserveSnapshotOnFailure: false)
    }

    func reload() async {
        hasLoaded = false
        await load(showLoading: true, preserveSnapshotOnFailure: false)
    }

    func refresh() async {
        await load(showLoading: dashboard == nil, preserveSnapshotOnFailure: true)
    }

    private func load(
        showLoading: Bool,
        preserveSnapshotOnFailure: Bool
    ) async {
        if showLoading && dashboard == nil {
            screenState = .loading
        }

        bannerMessage = nil

        do {
            let fetchedDashboard = try await fetchDashboard()
            dashboard = fetchedDashboard
            hasLoaded = true
            screenState = .loaded
        } catch let error as HomeServiceError {
            applyFailure(error, preserveSnapshotOnFailure: preserveSnapshotOnFailure)
        } catch {
            applyFailure(.networkUnavailable, preserveSnapshotOnFailure: preserveSnapshotOnFailure)
        }
    }

    private func applyFailure(
        _ error: HomeServiceError,
        preserveSnapshotOnFailure: Bool
    ) {
        if preserveSnapshotOnFailure, dashboard != nil {
            screenState = .loaded
            bannerMessage = .key("home.state.refreshFailed")
            return
        }

        screenState = .failed(error.textValue)
    }

    private func fetchDashboard() async throws -> HomeDashboardSnapshot {
        if let inFlightLoadTask {
            return try await awaitLoadResult(from: inFlightLoadTask)
        }

        let session = self.session
        let homeService = self.homeService
        let task = Task.detached(priority: .userInitiated) {
            try await homeService.fetchDashboard(session: session)
        }

        inFlightLoadTask = task
        defer {
            inFlightLoadTask = nil
        }

        return try await awaitLoadResult(from: task)
    }

    private func awaitLoadResult(
        from task: Task<HomeDashboardSnapshot, Error>
    ) async throws -> HomeDashboardSnapshot {
        try await withCheckedThrowingContinuation { continuation in
            Task.detached(priority: .userInitiated) {
                do {
                    continuation.resume(returning: try await task.value)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
