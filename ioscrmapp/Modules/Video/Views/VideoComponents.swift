import AVKit
import SwiftUI
import UIKit

struct VideoPalette {
    let theme: DUTheme

    var canvasBackground: Color { theme.colors.background.canvas }
    var panelBackground: Color { theme.colors.surface.card }
    var raisedBackground: Color { theme.colors.surface.raised }
    var secondaryBackground: Color { theme.colors.background.secondary }
    var tertiaryBackground: Color { theme.colors.background.tertiary }
    var inverseText: Color { theme.colors.text.inverse }
    var primaryText: Color { theme.colors.text.primary }
    var secondaryText: Color { theme.colors.text.secondary }
    var tertiaryText: Color { theme.colors.text.tertiary }
    var disabledText: Color { theme.colors.text.disabled }
    var subtleBorder: Color { theme.colors.border.subtle }
    var defaultBorder: Color { theme.colors.border.default }
    var accentText: Color { theme.colors.brand.secondary }
    var accentBackground: Color { theme.colors.brand.primaryBackground }
    var warningText: Color { theme.colors.status.warning }
    var warningBackground: Color { theme.colors.status.warningBackground }
    var cardElevation: DUElevationStyle { theme.components.card.elevation }
    var liftedElevation: DUElevationStyle { DUElevation.lifted }
    var spotlightElevation: DUElevationStyle { DUElevation.spotlight }
    var headerGradient: LinearGradient { theme.colors.gradient.brand }
    var placeholderGradient: LinearGradient { theme.colors.gradient.subtle }
    var darkOverlay: Color { DUColorPrimitives.Neutral.black.opacity(theme.resolvedColorScheme == .dark ? 0.62 : 0.84) }
    var mediaBackdrop: Color { DUColorPrimitives.Neutral.black }
    var mediaOverlay: Color { DUColorPrimitives.Neutral.black.opacity(theme.resolvedColorScheme == .dark ? 0.44 : 0.52) }
    var mediaCaptionBackground: Color { DUColorPrimitives.Neutral.black.opacity(0.72) }
    var mediaControlBackground: Color { DUColorPrimitives.Neutral.white.opacity(theme.resolvedColorScheme == .dark ? 0.18 : 0.22) }
    var mediaControlBorder: Color { DUColorPrimitives.Neutral.white.opacity(theme.resolvedColorScheme == .dark ? 0.26 : 0.32) }
    var mediaSecondaryText: Color { theme.colors.text.inverse.opacity(0.82) }
}

struct VideoImageView: View {
    @Environment(\.duTheme) private var theme

    let image: VideoImageSource
    var cornerRadius: CGFloat = 22
    var contentMode: ContentMode = .fill

    var body: some View {
        switch image {
        case let .remote(url):
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                default:
                    placeholder
                }
            }
        case let .asset(name):
            if let uiImage = UIImage(named: name) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                placeholder
            }
        case let .system(name, backgroundHex, tintHex):
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(hex: backgroundHex))
                .overlay(
                    Image(systemName: name)
                        .font(.du(.hero))
                        .foregroundColor(Color(hex: tintHex))
                )
        }
    }

    private var placeholder: some View {
        let palette = VideoPalette(theme: theme)

        return RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(palette.placeholderGradient)
            .overlay(
                Image(systemName: "play.rectangle.fill")
                    .font(.du(.headlineStrong))
                    .foregroundColor(palette.tertiaryText)
            )
    }
}

struct VideoSelectionChip: View {
    @Environment(\.duTheme) private var theme

    let title: String
    let isSelected: Bool

    var body: some View {
        let palette = VideoPalette(theme: theme)

        VStack(spacing: 6) {
            Text(title)
                .font(.du(.bodyStrong))
                .foregroundColor(isSelected ? palette.inverseText : palette.inverseText.opacity(0.78))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            Capsule()
                .fill(isSelected ? palette.inverseText : .clear)
                .frame(width: 20, height: 4)
        }
    }
}

struct VideoTagChip: View {
    @Environment(\.duTheme) private var theme

    let title: String
    let style: VideoTagStyle

    var body: some View {
        Text(title)
            .font(.du(.captionEmphasized))
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(backgroundColor)
            .clipShape(Capsule())
    }

    private var foregroundColor: Color {
        let palette = VideoPalette(theme: theme)

        switch style {
        case .neutral:
            return palette.secondaryText
        case .accent:
            return palette.accentText
        case .warning:
            return palette.warningText
        }
    }

    private var backgroundColor: Color {
        let palette = VideoPalette(theme: theme)

        switch style {
        case .neutral:
            return palette.secondaryBackground
        case .accent:
            return palette.accentBackground
        case .warning:
            return palette.warningBackground
        }
    }
}

struct VideoToastBanner: View {
    @Environment(\.duTheme) private var theme

    let message: String

    var body: some View {
        let palette = VideoPalette(theme: theme)

        HStack(spacing: DUSpacing.sm) {
            Image(systemName: "info.circle.fill")
                .font(.du(.bodyEmphasized))

            Text(message)
                .font(.du(.labelStrong))
                .lineLimit(2)
        }
        .foregroundColor(palette.inverseText)
        .padding(.horizontal, DUSpacing.lg)
        .padding(.vertical, DUSpacing.md)
        .background(palette.darkOverlay)
        .clipShape(Capsule())
        .shadow(color: palette.spotlightElevation.color, radius: palette.spotlightElevation.radius, x: palette.spotlightElevation.x, y: palette.spotlightElevation.y)
    }
}

struct VideoFeedCard: View {
    @Environment(\.duTheme) private var theme
    @EnvironmentObject private var languageStore: AppLanguageStore

    let content: VideoContentSummary
    let primaryCategoryTitle: String
    let action: () -> Void

    private let cardCornerRadius: CGFloat = 26
    private let posterAspectRatio: CGFloat = 2.0 / 3.0

    var body: some View {
        let palette = VideoPalette(theme: theme)

        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Color.clear
                .aspectRatio(posterAspectRatio, contentMode: .fit)
                .overlay {
                    VideoImageView(
                        image: content.posterImage,
                        cornerRadius: cardCornerRadius,
                        contentMode: .fill
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))

                VStack(alignment: .leading, spacing: DUSpacing.sm) {
                    Text(content.title.value(for: languageStore.currentLanguage))
                        .font(.du(.bodyLargeStrong))
                        .foregroundColor(palette.primaryText)
                        .lineLimit(2)
                        .frame(height: 42, alignment: .topLeading)

                    Text(content.summary.value(for: languageStore.currentLanguage))
                        .font(.du(.meta))
                        .foregroundColor(palette.secondaryText)
                        .lineLimit(2)
                        .frame(height: 36, alignment: .topLeading)

                    Text(primaryCategoryTitle)
                        .font(.du(.captionEmphasized))
                        .foregroundColor(palette.accentText)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .frame(height: 24)
                        .background(palette.accentBackground)
                        .clipShape(Capsule())

                    HStack(alignment: .center, spacing: DUSpacing.sm) {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.du(.captionEmphasized))

                            Text(content.ratingText ?? "--")
                                .font(.du(.captionEmphasized))
                        }
                        .foregroundColor(palette.warningText)
                        .environment(\.layoutDirection, .leftToRight)

                        Spacer(minLength: 0)

                        Text(content.durationText.value(for: languageStore.currentLanguage))
                            .font(.du(.caption))
                            .foregroundColor(palette.tertiaryText)
                            .lineLimit(1)
                    }
                    .frame(height: 18)
                }
                .padding(.horizontal, DUSpacing.md)
                .padding(.top, DUSpacing.md)
                .padding(.bottom, DUSpacing.lg)
            }
            .background(palette.panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
            .shadow(color: palette.cardElevation.color, radius: palette.cardElevation.radius, x: palette.cardElevation.x, y: palette.cardElevation.y)
        }
        .buttonStyle(.plain)
    }
}

struct VideoPlayerSurface: UIViewControllerRepresentable {
    let player: AVPlayer
    let pipEnabled: Bool

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.allowsPictureInPicturePlayback = pipEnabled
        controller.canStartPictureInPictureAutomaticallyFromInline = pipEnabled
        controller.updatesNowPlayingInfoCenter = false
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        if controller.player !== player {
            controller.player = player
        }
        controller.allowsPictureInPicturePlayback = pipEnabled
        controller.canStartPictureInPictureAutomaticallyFromInline = pipEnabled
    }
}

func configureCRMAudioSessionForPiP() {
    let session = AVAudioSession.sharedInstance()

    do {
        try session.setCategory(.playback, mode: .moviePlayback, options: [])
        try session.setActive(true)
    } catch {
        // Best-effort only. Playback can still proceed without PiP auto-activation.
    }
}

struct CRMSmartImage: View {
    @Environment(\.duTheme) private var theme

    let source: String
    var contentMode: ContentMode = .fill

    var body: some View {
        if source.hasPrefix("local:") {
            let imageName = String(source.dropFirst(6))
            if let image = loadLocalImage(named: imageName) ?? UIImage(named: imageName) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder
            }
        } else if let url = URL(string: source), url.scheme != nil {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    placeholder
                case let .success(image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                default:
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        let palette = VideoPalette(theme: theme)

        return Rectangle()
            .fill(palette.tertiaryBackground)
            .overlay {
                Image(systemName: "play.rectangle.fill")
                    .foregroundColor(palette.tertiaryText)
                    .font(.title2)
            }
    }

    private func loadLocalImage(named name: String) -> UIImage? {
        if let path = Bundle.main.path(
            forResource: name,
            ofType: "jpg",
            inDirectory: "Resources/Images"
        ) {
            return UIImage(contentsOfFile: path)
        }

        if let path = Bundle.main.path(
            forResource: name,
            ofType: "png",
            inDirectory: "Resources/Images"
        ) {
            return UIImage(contentsOfFile: path)
        }

        if let path = Bundle.main.path(forResource: name, ofType: "jpg") {
            return UIImage(contentsOfFile: path)
        }

        if let path = Bundle.main.path(forResource: name, ofType: "png") {
            return UIImage(contentsOfFile: path)
        }

        return nil
    }
}

struct CRMAvatarImage: View {
    @Environment(\.duTheme) private var theme

    let source: String?
    var size: CGFloat = 60

    var body: some View {
        let palette = VideoPalette(theme: theme)

        Group {
            if let source, !source.isEmpty {
                CRMSmartImage(source: source, contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(palette.tertiaryBackground)
                    .frame(width: size, height: size)
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundColor(palette.tertiaryText)
                            .font(.title2)
                    }
            }
        }
    }
}

struct CRMBackButton: View {
    @Environment(\.duTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let palette = VideoPalette(theme: theme)

        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.title2)
                .foregroundColor(palette.inverseText)
                .padding(8)
                .background(DUColorPrimitives.Neutral.black.opacity(0.3))
                .clipShape(Circle())
        }
    }
}

struct CRMCustomVideoPlayer: UIViewRepresentable {
    let player: AVPlayer
    var onPlayerLayerReady: ((AVPlayerLayer) -> Void)?

    func makeUIView(context: Context) -> CRMPlayerPlatformView {
        let view = CRMPlayerPlatformView()
        view.onPlayerLayerReady = onPlayerLayerReady
        view.player = player
        return view
    }

    func updateUIView(_ uiView: CRMPlayerPlatformView, context: Context) {
        if uiView.player !== player {
            uiView.player = player
        }
    }
}

final class CRMPlayerPlatformView: UIView {
    private var playerLayer: AVPlayerLayer?
    private var hasNotifiedReady = false

    var onPlayerLayerReady: ((AVPlayerLayer) -> Void)?

    var player: AVPlayer? {
        didSet {
            if playerLayer == nil {
                let layer = AVPlayerLayer()
                layer.videoGravity = .resizeAspect
                self.layer.addSublayer(layer)
                playerLayer = layer
            }

            playerLayer?.player = player

            if let playerLayer, player != nil, !hasNotifiedReady {
                hasNotifiedReady = true
                DispatchQueue.main.async {
                    self.onPlayerLayerReady?(playerLayer)
                }
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }
}

extension View {
    @ViewBuilder
    func crmApplyInlineNavigationTitleDisplayMode() -> some View {
        navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    func crmApplyHiddenNavigationChrome() -> some View {
        navigationBarHidden(true)
            .statusBar(hidden: true)
    }
}
