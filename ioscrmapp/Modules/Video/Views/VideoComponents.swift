import AVKit
import SwiftUI
import UIKit

enum VideoTheme {
    static let headerGradient = LinearGradient(
        colors: [
            Color(hex: 0x081B33),
            Color(hex: 0x0B4F80),
            Color(hex: 0x2452C7),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
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
        Text(title)
            .font(.du(13, weight: isSelected ? .bold : .semibold))
            .foregroundColor(isSelected ? .white : DUTheme.inkSecondary)
            .padding(.horizontal, DUSpacing.md)
            .frame(height: 36)
            .background(backgroundView)
            .clipShape(Capsule())
    }

    @ViewBuilder
    private var backgroundView: some View {
        if isSelected {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [DUTheme.cyan, DUTheme.blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        } else {
            Capsule()
                .fill(Color.white.opacity(0.16))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
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
    let action: () -> Void

    private let posterHeight: CGFloat = 220
    private let cardCornerRadius: CGFloat = 26

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    VideoImageView(
                        image: content.posterImage,
                        cornerRadius: cardCornerRadius,
                        contentMode: .fill
                    )

                    VStack(alignment: .leading, spacing: DUSpacing.sm) {
                        if let badgeText = content.badgeText?.value(for: languageStore.currentLanguage) {
                            Text(badgeText)
                                .font(.du(11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .frame(height: 24)
                                .background(
                                    LinearGradient(
                                        colors: [Color(hex: 0xFF7A18), Color(hex: 0xAF002D)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(Capsule())
                        }

                        Spacer()

                        if !content.isPlayable {
                            Text(content.availabilityMessage?.value(for: languageStore.currentLanguage) ?? "")
                                .font(.du(11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .frame(height: 26)
                                .background(Color.black.opacity(0.64))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(DUSpacing.md)
                }
                .frame(height: posterHeight)
                .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))

                VStack(alignment: .leading, spacing: DUSpacing.sm) {
                    HStack(alignment: .top, spacing: DUSpacing.xs) {
                        Text(content.title.value(for: languageStore.currentLanguage))
                            .font(.du(15, weight: .bold))
                            .foregroundColor(DUTheme.ink)
                            .lineLimit(2)

                        Spacer(minLength: 0)

                        if let ratingText = content.ratingText {
                            HStack(spacing: 3) {
                                Image(systemName: "star.fill")
                                    .font(.du(11, weight: .bold))
                                Text(ratingText)
                                    .font(.du(11, weight: .bold))
                            }
                            .foregroundColor(Color(hex: 0xF59E0B))
                            .environment(\.layoutDirection, .leftToRight)
                        }
                    }

                    Text(content.subtitle.value(for: languageStore.currentLanguage))
                        .font(.du(12, weight: .medium))
                        .foregroundColor(DUTheme.inkSecondary)
                        .lineLimit(2)
                        .frame(minHeight: 34, alignment: .topLeading)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(content.chips.indices, id: \.self) { index in
                                VideoTagChip(
                                    title: content.chips[index].value(for: languageStore.currentLanguage),
                                    style: index == 0 ? .accent : .neutral
                                )
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(content.metaLine.value(for: languageStore.currentLanguage))
                            .font(.du(11, weight: .semibold))
                            .foregroundColor(DUTheme.inkSecondary)
                            .lineLimit(2)

                        Text(content.durationText.value(for: languageStore.currentLanguage))
                            .font(.du(11, weight: .medium))
                            .foregroundColor(DUTheme.inkTertiary)
                    }
                    .frame(minHeight: 42, alignment: .topLeading)
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
