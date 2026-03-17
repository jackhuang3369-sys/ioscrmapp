import SwiftUI

struct AppLaunchContainerView<Content: View>: View {
    @StateObject private var viewModel: AppLaunchContainerViewModel

    private let content: Content

    init(
        splashAdService: any SplashAdServicing,
        @ViewBuilder content: () -> Content
    ) {
        _viewModel = StateObject(
            wrappedValue: AppLaunchContainerViewModel(splashAdService: splashAdService)
        )
        self.content = content()
    }

    var body: some View {
        Group {
            switch viewModel.route {
            case .resolving:
                Color.clear
                    .ignoresSafeArea()
            case .content:
                content
            case let .splashAd(playableAd):
                SplashAdView(playableAd: playableAd) { _ in
                    viewModel.finishSplashAd()
                }
            }
        }
        .task {
            viewModel.startIfNeeded()
        }
    }
}
