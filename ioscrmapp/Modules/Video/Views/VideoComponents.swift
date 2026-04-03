import AVKit
import SwiftUI
import UIKit

enum VideoTheme {
    static let headerGradient = DUTheme.brandGradient
}

struct VideoImageView: View {
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
                        .font(.du(28, weight: .semibold))
                        .foregroundColor(Color(hex: tintHex))
                )
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(hex: 0xDAE8F7),
                        Color(hex: 0xEFF4FA),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: "play.rectangle.fill")
                    .font(.du(26, weight: .bold))
                    .foregroundColor(Color(hex: 0x4B6A88))
            )
    }
}

struct VideoSelectionChip: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.du(14, weight: .semibold))
                .foregroundColor(isSelected ? .white : .white.opacity(0.78))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            Capsule()
                .fill(isSelected ? Color.white : .clear)
                .frame(width: 20, height: 4)
        }
    }
}

struct VideoTagChip: View {
    let title: String
    let style: VideoTagStyle

    var body: some View {
        Text(title)
            .font(.du(11, weight: .bold))
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(backgroundColor)
            .clipShape(Capsule())
    }

    private var foregroundColor: Color {
        switch style {
        case .neutral:
            return DUTheme.inkSecondary
        case .accent:
            return Color(hex: 0x0C4A6E)
        case .warning:
            return Color(hex: 0x9A3412)
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .neutral:
            return DUTheme.backgroundSecondary
        case .accent:
            return Color(hex: 0xD9F0FF)
        case .warning:
            return Color(hex: 0xFFF0D8)
        }
    }
}

struct VideoToastBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: DUSpacing.sm) {
            Image(systemName: "info.circle.fill")
                .font(.du(14, weight: .bold))

            Text(message)
                .font(.du(13, weight: .semibold))
                .lineLimit(2)
        }
        .foregroundColor(.white)
        .padding(.horizontal, DUSpacing.lg)
        .padding(.vertical, DUSpacing.md)
        .background(Color.black.opacity(0.84))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.16), radius: 18, x: 0, y: 10)
    }
}

struct VideoFeedCard: View {
    @EnvironmentObject private var languageStore: AppLanguageStore

    let content: VideoContentSummary
    let primaryCategoryTitle: String
    let action: () -> Void

    private let cardCornerRadius: CGFloat = 26
    private let posterAspectRatio: CGFloat = 2.0 / 3.0

    var body: some View {
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
                        .font(.du(15, weight: .bold))
                        .foregroundColor(DUTheme.ink)
                        .lineLimit(2)
                        .frame(height: 42, alignment: .topLeading)

                    Text(content.summary.value(for: languageStore.currentLanguage))
                        .font(.du(12, weight: .medium))
                        .foregroundColor(DUTheme.inkSecondary)
                        .lineLimit(2)
                        .frame(height: 36, alignment: .topLeading)

                    Text(primaryCategoryTitle)
                        .font(.du(11, weight: .bold))
                        .foregroundColor(Color(hex: 0x0C4A6E))
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .frame(height: 24)
                        .background(Color(hex: 0xD9F0FF))
                        .clipShape(Capsule())

                    HStack(alignment: .center, spacing: DUSpacing.sm) {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.du(11, weight: .bold))

                            Text(content.ratingText ?? "--")
                                .font(.du(11, weight: .bold))
                        }
                        .foregroundColor(Color(hex: 0xF59E0B))
                        .environment(\.layoutDirection, .leftToRight)

                        Spacer(minLength: 0)

                        Text(content.durationText.value(for: languageStore.currentLanguage))
                            .font(.du(11, weight: .medium))
                            .foregroundColor(DUTheme.inkTertiary)
                            .lineLimit(1)
                    }
                    .frame(height: 18)
                }
                .padding(.horizontal, DUSpacing.md)
                .padding(.top, DUSpacing.md)
                .padding(.bottom, DUSpacing.lg)
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
            .shadow(color: Color.black.opacity(0.07), radius: 18, x: 0, y: 10)
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
        Rectangle()
            .fill(Color.gray.opacity(0.24))
            .overlay {
                Image(systemName: "play.rectangle.fill")
                    .foregroundColor(.gray)
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
    let source: String?
    var size: CGFloat = 60

    var body: some View {
        Group {
            if let source, !source.isEmpty {
                CRMSmartImage(source: source, contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: size, height: size)
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                            .font(.title2)
                    }
            }
        }
    }
}

struct CRMBackButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.title2)
                .foregroundColor(.white)
                .padding(8)
                .background(Color.black.opacity(0.3))
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
