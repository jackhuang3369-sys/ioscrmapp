import Foundation

@MainActor
final class AppLaunchContainerViewModel: ObservableObject {
    enum Route: Equatable {
        case resolving
        case splashAd(SplashAdPlayable)
        case content
    }

    @Published private(set) var route: Route = .resolving

    private let splashAdService: any SplashAdServicing
    private var launchTask: Task<Void, Never>?

    init(splashAdService: any SplashAdServicing) {
        self.splashAdService = splashAdService
    }

    deinit {
        launchTask?.cancel()
    }

    func startIfNeeded() {
        guard launchTask == nil else {
            return
        }

        launchTask = Task { [weak self] in
            guard let self else {
                return
            }

            let playableAd = await splashAdService.loadPlayableAd()
            route = playableAd.map(Route.splashAd) ?? .content

            Task(priority: .utility) {
                await self.splashAdService.refreshSplashAdCache()
            }
        }
    }

    func finishSplashAd() {
        route = .content
    }
}
