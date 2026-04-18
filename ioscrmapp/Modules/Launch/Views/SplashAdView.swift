import AVFoundation
import SwiftUI

struct SplashAdView: View {
    @Environment(\.duTheme) private var theme
    @EnvironmentObject private var languageStore: AppLanguageStore

    @StateObject private var viewModel: SplashAdViewModel

    init(
        playableAd: SplashAdPlayable,
        onFinish: @escaping (SplashAdFinishReason) -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: SplashAdViewModel(
                playableAd: playableAd,
                onFinish: onFinish
            )
        )
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                DUColorPrimitives.Neutral.black
                    .ignoresSafeArea()

                SplashAdPlayerSurface(player: viewModel.player)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DUColorPrimitives.Neutral.black)
                    .ignoresSafeArea()

                if viewModel.isLoading || viewModel.failureMessage != nil {
                    loadingOverlay
                }
            }
            .overlay(alignment: .topTrailing) {
                DUSplashSkipButton(
                    title: languageStore.string(viewModel.buttonText),
                    progress: viewModel.progress,
                    isEnabled: viewModel.isSkipEnabled
                ) {
                    viewModel.skipIfAvailable()
                }
                .padding(.top, proxy.safeAreaInsets.top + DUSpacing.sm)
                .padding(.horizontal, DUSpacing.lg)
            }
            .overlay(alignment: .bottomTrailing) {
                DUSplashAudioButton(
                    accessibilityLabel: languageStore.string(viewModel.audioButtonText),
                    systemImageName: viewModel.audioButtonSystemImageName
                ) {
                    viewModel.toggleMuted()
                }
                .padding(.trailing, DUSpacing.lg)
                .padding(.bottom, max(proxy.safeAreaInsets.bottom, DUSpacing.lg))
            }
        }
        .task {
            viewModel.startIfNeeded()
        }
        .onDisappear {
            viewModel.stop()
        }
    }

    private var loadingOverlay: some View {
        VStack(spacing: DUSpacing.md) {
            ProgressView()
                .controlSize(.large)
                .tint(DUColorPrimitives.Neutral.white)

            if let failureMessage = viewModel.failureMessage {
                Text(languageStore.string(failureMessage))
                    .font(.du(.label))
                    .foregroundColor(DUColorPrimitives.Neutral.white)
                    .padding(.horizontal, DUSpacing.lg)
                    .padding(.vertical, DUSpacing.sm)
                    .background(theme.colors.chrome.splash)
                    .clipShape(Capsule())
            }
        }
        .padding(DUSpacing.xxl)
        .background(theme.colors.chrome.splash)
        .clipShape(RoundedRectangle(cornerRadius: theme.components.sheet.cornerRadius, style: .continuous))
    }
}

private struct SplashAdPlayerSurface: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> SplashAdPlayerView {
        let view = SplashAdPlayerView()
        //完整展示，不裁剪
        view.backgroundColor = .black
        view.playerLayer.videoGravity = .resizeAspect
        //完整展示，不裁剪
        //自适应屏幕
//        view.playerLayer.videoGravity = .resizeAspectFill
        //自适应屏幕
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: SplashAdPlayerView, context: Context) {
        uiView.playerLayer.player = player
    }
}

private final class SplashAdPlayerView: UIView {
    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}
