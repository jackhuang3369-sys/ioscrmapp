import AVFoundation
import AVKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct CRMVideoDetailContent: View {
    @Environment(\.duTheme) private var theme
    @EnvironmentObject private var languageStore: AppLanguageStore

    let detail: VideoDetailSnapshot
    let selectedEpisodeID: String?
    let isRequestingPlayback: Bool
    let onSelectEpisode: (VideoEpisode) -> Void
    let onPlay: () -> Void
    let onSelectRelated: (String) -> Void

    @State private var isDescriptionExpanded = false

    private var episodes: [VideoEpisode] {
        detail.episodeGroups.flatMap(\.episodes)
    }

    private var selectedEpisode: VideoEpisode? {
        episodes.first { $0.id == selectedEpisodeID } ?? detail.defaultEpisode
    }

    var body: some View {
        let palette = VideoPalette(theme: theme)

        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                infoSection
                descriptionSection

                Divider()
                    .padding(.horizontal)

                if episodes.count > 1 {
                    episodeSection
                }

                if !detail.cast.isEmpty {
                    castSection
                }

                Divider()
                    .padding(.horizontal)

                relatedSection
            }
            .padding(.bottom, DUSpacing.xxxxl)
        }
        .background(palette.canvasBackground)
        .crmApplyInlineNavigationTitleDisplayMode()
    }

    private var headerSection: some View {
        let palette = VideoPalette(theme: theme)

        return ZStack(alignment: .bottomLeading) {
            VideoImageView(
                image: detail.heroImage,
                cornerRadius: 0,
                contentMode: .fill
            )
            .frame(height: 250)
            .clipped()
            .blur(radius: 20)
            .overlay(DUColorPrimitives.Neutral.black.opacity(0.32))

            HStack(alignment: .bottom, spacing: 16) {
                VideoImageView(
                    image: detail.content.posterImage,
                    cornerRadius: DURadius.sm,
                    contentMode: .fill
                )
                .frame(width: 120, height: 170)
                .clipShape(RoundedRectangle(cornerRadius: DURadius.sm, style: .continuous))
                .shadow(color: palette.liftedElevation.color, radius: palette.liftedElevation.radius, x: palette.liftedElevation.x, y: palette.liftedElevation.y)

                VStack(alignment: .leading, spacing: 8) {
                    Text(detail.content.title.value(for: languageStore.currentLanguage))
                        .font(.du(.titleStrong))
                        .foregroundColor(palette.inverseText)
                        .lineLimit(2)

                    if let ratingText = detail.content.ratingText {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(palette.warningText)

                            Text(ratingText)
                                .font(.du(.bodyStrong))
                                .foregroundColor(palette.inverseText)
                        }
                        .font(.du(.body))
                        .environment(\.layoutDirection, .leftToRight)
                    }

                    if !detail.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(detail.tags.prefix(3)) { tag in
                                    Text(tag.title.value(for: languageStore.currentLanguage))
                                        .font(.du(.caption))
                                        .foregroundColor(palette.inverseText.opacity(0.92))
                                        .padding(.horizontal, DUSpacing.sm)
                                        .padding(.vertical, DUSpacing.xs)
                                        .background(palette.inverseText.opacity(0.2))
                                        .clipShape(RoundedRectangle(cornerRadius: DURadius.xs, style: .continuous))
                                }
                            }
                        }
                    }

                    if let selectedEpisode {
                        Text(selectedEpisode.title.value(for: languageStore.currentLanguage))
                            .font(.du(.caption))
                            .foregroundColor(palette.inverseText.opacity(0.82))
                            .lineLimit(1)
                    }

                    Button(action: onPlay) {
                        HStack(spacing: 8) {
                            if isRequestingPlayback {
                                ProgressView()
                                    .tint(palette.inverseText)
                            } else {
                                Image(systemName: "play.fill")
                            }

                            Text(localized("video.detail.playNow"))
                                .font(.du(.bodyStrong))
                        }
                        .foregroundColor(palette.inverseText)
                        .padding(.horizontal, DUSpacing.xl)
                        .padding(.vertical, DUSpacing.base)
                        .background(detail.isPlayable ? theme.colors.brand.secondary : palette.disabledText.opacity(0.45))
                        .clipShape(Capsule())
                    }
                    .disabled(!detail.isPlayable || selectedEpisode == nil || isRequestingPlayback)

                    if !detail.isPlayable {
                        Text(
                            detail.content.availabilityMessage?.value(for: languageStore.currentLanguage)
                                ?? localized("video.unavailable.noSource.title")
                        )
                        .font(.du(.caption))
                        .foregroundColor(palette.inverseText.opacity(0.88))
                        .lineLimit(2)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding()
        }
    }

    private var infoSection: some View {
        let palette = VideoPalette(theme: theme)

        return HStack(spacing: DUSpacing.lg) {
            ForEach(detail.stats) { stat in
                VStack(spacing: 6) {
                    Image(systemName: stat.systemImage)
                        .font(.du(.titleSmall))
                        .foregroundColor(color(for: stat.id))

                    Text(stat.value)
                        .font(.du(.bodyStrong))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .environment(\.layoutDirection, .leftToRight)

                    Text(localized(stat.titleKey))
                        .font(.du(.caption))
                        .foregroundColor(palette.secondaryText)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, DUSpacing.sm)
    }

    private var descriptionSection: some View {
        let palette = VideoPalette(theme: theme)

        return VStack(alignment: .leading, spacing: DUSpacing.sm) {
            Text(localized("video.detail.synopsis"))
                .font(.du(.bodyLargeStrong))
                .foregroundColor(palette.primaryText)

            Text(detail.synopsis.value(for: languageStore.currentLanguage))
                .font(.du(.body))
                .foregroundColor(palette.secondaryText)
                .lineLimit(isDescriptionExpanded ? nil : 3)

            Button(action: toggleDescription) {
                Text(expandActionTitle)
                    .font(.du(.captionStrong))
                    .foregroundColor(palette.accentText)
            }
        }
        .padding(.horizontal)
    }

    private var episodeSection: some View {
        let palette = VideoPalette(theme: theme)

        return VStack(alignment: .leading, spacing: DUSpacing.md) {
            Text("\(localized("video.detail.episodes")) (\(episodes.count))")
                .font(.du(.headline))
                .foregroundColor(palette.primaryText)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DUSpacing.md) {
                    ForEach(episodes) { episode in
                        Button {
                            onSelectEpisode(episode)
                        } label: {
                            VStack(spacing: DUSpacing.sm) {
                                ZStack {
                                    VideoImageView(
                                        image: episode.thumbnailImage,
                                        cornerRadius: DURadius.sm,
                                        contentMode: .fill
                                    )
                                    .frame(width: 96, height: 64)
                                    .clipShape(RoundedRectangle(cornerRadius: DURadius.sm, style: .continuous))

                                    palette.mediaOverlay.opacity(0.72)
                                        .clipShape(RoundedRectangle(cornerRadius: DURadius.sm, style: .continuous))

                                    Image(systemName: "play.circle.fill")
                                        .font(.du(.title))
                                        .foregroundColor(palette.inverseText)
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: DURadius.sm, style: .continuous)
                                        .stroke(
                                            selectedEpisodeID == episode.id ? palette.accentText : .clear,
                                            lineWidth: 2
                                        )
                                )

                                Text(episode.title.value(for: languageStore.currentLanguage))
                                    .font(.du(.captionStrong))
                                    .foregroundColor(palette.primaryText)
                                    .lineLimit(1)

                                Text(formattedDuration(episode.durationSeconds))
                                    .font(.du(.tiny))
                                    .foregroundColor(palette.secondaryText)
                            }
                            .frame(width: 96)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var castSection: some View {
        let palette = VideoPalette(theme: theme)

        return VStack(alignment: .leading, spacing: DUSpacing.md) {
            Text(localized("video.detail.cast"))
                .font(.du(.headline))
                .foregroundColor(palette.primaryText)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DUSpacing.lg) {
                    ForEach(detail.cast) { member in
                        VStack(spacing: DUSpacing.sm) {
                            if let avatarImage = member.avatarImage {
                                VideoImageView(
                                    image: avatarImage,
                                    cornerRadius: DURadius.pill,
                                    contentMode: .fill
                                )
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(palette.tertiaryBackground)
                                    .frame(width: 60, height: 60)
                                    .overlay {
                                        Image(systemName: "person.fill")
                                            .foregroundColor(palette.tertiaryText)
                                    }
                            }

                            Text(member.name)
                                .font(.du(.captionStrong))
                                .foregroundColor(palette.primaryText)
                                .lineLimit(1)

                            if let role = member.role {
                                Text(role.value(for: languageStore.currentLanguage))
                                    .font(.du(.tiny))
                                    .foregroundColor(palette.secondaryText)
                                    .lineLimit(1)
                            }
                        }
                        .frame(width: 72)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var relatedSection: some View {
        let palette = VideoPalette(theme: theme)

        return VStack(alignment: .leading, spacing: DUSpacing.md) {
            Text(localized("video.detail.related"))
                .font(.du(.headline))
                .foregroundColor(palette.primaryText)
                .padding(.horizontal)

            if detail.related.isEmpty {
                Text(localized("video.state.error.subtitle"))
                    .font(.du(.body))
                    .foregroundColor(palette.secondaryText)
                    .padding(.horizontal)
            } else {
                VStack(spacing: DUSpacing.md) {
                    ForEach(detail.related) { related in
                        Button {
                            onSelectRelated(related.id)
                        } label: {
                            CRMRelatedVideoRow(
                                content: related,
                                typeTitle: typeTitle(for: related.type),
                                language: languageStore.currentLanguage
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var expandActionTitle: String {
        switch languageStore.currentLanguage {
        case .simplifiedChinese:
            return isDescriptionExpanded ? "收起" : "展开"
        case .english:
            return isDescriptionExpanded ? "Less" : "More"
        case .arabic:
            return isDescriptionExpanded ? "أقل" : "المزيد"
        }
    }

    private func localized(_ key: String) -> String {
        languageStore.string(key)
    }

    private func toggleDescription() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isDescriptionExpanded.toggle()
        }
    }

    private func formattedDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h\(minutes)m"
        }

        return "\(max(1, minutes)) min"
    }

    private func color(for statID: String) -> Color {
        let palette = VideoPalette(theme: theme)

        switch statID {
        case "views":
            return theme.colors.brand.primary
        case "released":
            return theme.colors.status.success
        case "episodes":
            return palette.warningText
        case "duration":
            return theme.colors.brand.indigo
        default:
            return palette.accentText
        }
    }

    private func typeTitle(for type: VideoContentType) -> String {
        switch type {
        case .movie:
            return VideoLocalizedString("电影", "Movie", "أفلام")
                .value(for: languageStore.currentLanguage)
        case .series:
            return VideoLocalizedString("剧集", "Series", "مسلسلات")
                .value(for: languageStore.currentLanguage)
        case .variety:
            return VideoLocalizedString("综艺", "Variety", "منوعات")
                .value(for: languageStore.currentLanguage)
        case .documentary:
            return VideoLocalizedString("纪录片", "Documentary", "وثائقي")
                .value(for: languageStore.currentLanguage)
        }
    }
}

private struct CRMRelatedVideoRow: View {
    @Environment(\.duTheme) private var theme

    let content: VideoContentSummary
    let typeTitle: String
    let language: AppLanguage

    var body: some View {
        let palette = VideoPalette(theme: theme)

        return HStack(spacing: DUSpacing.md) {
            VideoImageView(
                image: content.posterImage,
                cornerRadius: DURadius.xs,
                contentMode: .fill
            )
            .frame(width: 100, height: 70)
            .clipShape(RoundedRectangle(cornerRadius: DURadius.xs, style: .continuous))

            VStack(alignment: .leading, spacing: DUSpacing.xs) {
                Text(content.title.value(for: language))
                    .font(.du(.bodyStrong))
                    .foregroundColor(palette.primaryText)
                    .lineLimit(2)

                HStack {
                    if let ratingText = content.ratingText {
                        Label(ratingText, systemImage: "star.fill")
                            .font(.du(.caption))
                            .foregroundColor(palette.warningText)
                            .environment(\.layoutDirection, .leftToRight)
                    }

                    Text(typeTitle)
                        .font(.du(.caption))
                        .foregroundColor(palette.secondaryText)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.du(.caption))
                .foregroundColor(palette.disabledText)
        }
        .padding(.vertical, DUSpacing.xs)
    }
}

struct CRMVideoPlayExperience: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.duTheme) private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var languageStore: AppLanguageStore

    let detail: VideoDetailSnapshot
    let sessionInfo: CustSubInfo
    let videoService: any VideoServicing

    @State private var playbackSession: VideoPlaybackSession
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var showControls = true
    @State private var currentQuality: VideoQuality
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var isSeeking = false
    @State private var currentSubtitle: VideoSubtitleTrack?
    @State private var currentAudioTrack: VideoAudioTrack?
    @State private var subtitleText = ""
    @State private var subtitleCues: [CRMSubtitleCue] = []
    @State private var pipController: AVPictureInPictureController?
    @State private var playerLayer: AVPlayerLayer?
    @State private var timeObserverToken: Any?
    @State private var isSwitchingEpisode = false
    @State private var isPictureInPictureActive = false
    @State private var isPictureInPictureStarting = false
    @State private var shouldCleanupAfterPictureInPictureStops = false
    @ObservedObject var presentationCoordinator: CRMVideoPlayerPresentationCoordinator

    init(
        detail: VideoDetailSnapshot,
        initialSession: VideoPlaybackSession,
        sessionInfo: CustSubInfo,
        videoService: any VideoServicing,
        presentationCoordinator: CRMVideoPlayerPresentationCoordinator
    ) {
        self.detail = detail
        self.sessionInfo = sessionInfo
        self.videoService = videoService
        self.presentationCoordinator = presentationCoordinator
        _playbackSession = State(initialValue: initialSession)
        _currentQuality = State(
            initialValue: initialSession.episode.resolutions.first?.quality ?? .auto
        )
        _currentSubtitle = State(
            initialValue: initialSession.episode.subtitleTracks.first(where: { $0.languageCode == "off" })
                ?? initialSession.episode.subtitleTracks.first
        )
        _currentAudioTrack = State(
            initialValue: initialSession.episode.audioTracks.first(where: \.isDefault)
                ?? initialSession.episode.audioTracks.first
        )
    }

    private var allEpisodes: [VideoEpisode] {
        detail.episodeGroups.flatMap(\.episodes)
    }

    private var availableVideoQualities: [VideoQuality] {
        playbackSession.episode.resolutions
            .map(\.quality)
            .uniqued()
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        let palette = VideoPalette(theme: theme)

        GeometryReader { _ in
            ZStack {
                palette.mediaBackdrop
                    .ignoresSafeArea()

                if let player {
                    CRMCustomVideoPlayer(player: player) { layer in
                        playerLayer = layer
                        setupPiP(with: layer)
                    }
                    .ignoresSafeArea()
                } else {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(palette.inverseText)
                }

                if !subtitleText.isEmpty {
                    VStack {
                        Spacer()

                        Text(subtitleText)
                            .font(.du(.bodyStrong))
                            .foregroundColor(palette.inverseText)
                            .padding(.horizontal, DUSpacing.lg)
                            .padding(.vertical, DUSpacing.sm)
                            .background(palette.mediaCaptionBackground)
                            .clipShape(RoundedRectangle(cornerRadius: DURadius.xs, style: .continuous))
                            .padding(.bottom, showControls ? 120 : 50)
                    }
                }

                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        toggleControls()
                    }

                if showControls {
                    controlOverlay
                }
            }
        }
        .crmApplyHiddenNavigationChrome()
        .onAppear {
            configurePictureInPictureCallbacks()
            shouldCleanupAfterPictureInPictureStops = false
            if presentationCoordinator.shouldForceFullscreenOnNextAppear {
                presentationCoordinator.shouldForceFullscreenOnNextAppear = false
                enterFullscreenPlaybackMode()
            }
            if restoreRetainedPlaybackIfNeeded() {
                presentationCoordinator.completePictureInPictureRestoreIfNeeded()
            } else if player == nil {
                if presentationCoordinator.isRestoringFromPictureInPicture {
                    applyRetainedPlaybackSnapshot()
                    setupPlayer(
                        initialTime: presentationCoordinator.retainedPlaybackTime,
                        shouldAutoPlay: presentationCoordinator.retainedWasPlaying
                    )
                    presentationCoordinator.completePictureInPictureRestoreIfNeeded()
                } else {
                    setupPlayer()
                }
            }
        }
        .onDisappear {
            presentationCoordinator.pictureInPictureCoordinator.onStateChange = nil
            presentationCoordinator.pictureInPictureCoordinator.onRestoreInterface = nil
            presentationCoordinator.pictureInPictureCoordinator.onFailure = nil
            handlePlayerViewDisappear()
        }
    }

    private var controlOverlay: some View {
        let palette = VideoPalette(theme: theme)

        return VStack {
            topBar
                .padding(.horizontal)
                .padding(.top)

            Spacer()

            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleControls()
                }

            Spacer()

            centerControls

            Spacer()

            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleControls()
                }

            Spacer()

            bottomBar
                .padding(.horizontal)
                .padding(.bottom)
        }
        .background(palette.mediaOverlay.ignoresSafeArea())
        .transition(.opacity)
    }

    private var topBar: some View {
        let palette = VideoPalette(theme: theme)

        return HStack {
            CRMBackButton()

            Spacer()

            VStack(spacing: 2) {
                Text(playbackSession.mediaTitle.value(for: languageStore.currentLanguage))
                    .font(.du(.headline))
                    .foregroundColor(palette.inverseText)
                    .lineLimit(1)

                Text(playbackSession.episode.title.value(for: languageStore.currentLanguage))
                    .font(.du(.body))
                    .foregroundColor(palette.mediaSecondaryText)
                    .lineLimit(1)
            }

            Spacer()

            if allEpisodes.count > 1 {
                Menu {
                    ForEach(allEpisodes) { episode in
                        Button {
                            Task {
                                await switchEpisode(to: episode)
                            }
                        } label: {
                            HStack {
                                Text(episode.title.value(for: languageStore.currentLanguage))
                                if episode.id == playbackSession.episode.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.du(.titleSmall))
                        .foregroundColor(palette.inverseText)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Button(action: {}) {
                    Image(systemName: "ellipsis")
                        .font(.du(.title))
                        .foregroundColor(palette.inverseText)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var centerControls: some View {
        let palette = VideoPalette(theme: theme)

        return HStack(spacing: 60) {
            Button {
                seek(by: -10)
            } label: {
                Image(systemName: "gobackward.10")
                    .font(.du(.title))
                    .foregroundColor(palette.inverseText)
                    .frame(width: 60, height: 60)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                togglePlayPause()
            } label: {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.du(.display))
                    .foregroundColor(palette.inverseText)
                    .frame(width: 80, height: 80)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                seek(by: 10)
            } label: {
                Image(systemName: "goforward.10")
                    .font(.du(.title))
                    .foregroundColor(palette.inverseText)
                    .frame(width: 60, height: 60)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var bottomBar: some View {
        let palette = VideoPalette(theme: theme)

        return VStack(spacing: 12) {
            HStack(spacing: 10) {
                Text(formatTime(currentTime))
                    .font(.du(.caption))
                    .foregroundColor(palette.inverseText)
                    .monospacedDigit()

                Slider(
                    value: $currentTime,
                    in: 0 ... max(duration, 1),
                    onEditingChanged: { editing in
                        isSeeking = editing
                        if !editing {
                            seekTo(time: currentTime)
                        }
                    }
                )
                .tint(palette.inverseText)

                Text(formatTime(duration))
                    .font(.du(.caption))
                    .foregroundColor(palette.inverseText)
                    .monospacedDigit()
            }

            HStack(spacing: 16) {
                playbackSelectionControls
                    .frame(maxWidth: .infinity, alignment: .leading)

                playbackActionButtons
            }

            if isSwitchingEpisode {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(palette.inverseText)

                    Text(languageStore.string("video.player.loading"))
                        .font(.du(.caption))
                        .foregroundColor(palette.mediaSecondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var playbackSelectionControls: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                qualityControl
                subtitleControl
                audioTrackControl
            }
            .padding(.trailing, DUSpacing.xs)
        }
    }

    private var playbackActionButtons: some View {
        HStack(spacing: 16) {
            pictureInPictureButton
            fullscreenButton
        }
        .frame(alignment: .trailing)
    }

    private var qualityControl: some View {
        Menu {
            ForEach(availableVideoQualities, id: \.self) { quality in
                Button {
                    switchQuality(to: quality)
                } label: {
                    HStack {
                        Text(quality.title(for: languageStore.currentLanguage))
                        if quality == currentQuality {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            controlPill(
                icon: "gearshape",
                text: currentQuality.title(for: languageStore.currentLanguage)
            )
        }
    }

    private var subtitleControl: some View {
        Menu {
            ForEach(playbackSession.episode.subtitleTracks) { subtitle in
                Button {
                    switchSubtitle(to: subtitle)
                } label: {
                    HStack {
                        Text(subtitle.displayName.value(for: languageStore.currentLanguage))
                        if currentSubtitle?.id == subtitle.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            controlPill(
                icon: "captions.bubble",
                text: currentSubtitle?.displayName.value(for: languageStore.currentLanguage)
                    ?? localizedFallback("字幕", "Subtitles", "الترجمة")
            )
        }
    }

    private var audioTrackControl: some View {
        Menu {
            ForEach(playbackSession.episode.audioTracks) { track in
                Button {
                    switchAudioTrack(to: track)
                } label: {
                    HStack {
                        Text(track.displayName.value(for: languageStore.currentLanguage))
                        if currentAudioTrack?.id == track.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            controlPill(
                icon: "waveform",
                text: currentAudioTrack?.displayName.value(for: languageStore.currentLanguage)
                    ?? localizedFallback("音轨", "Audio", "الصوت")
            )
        }
    }

    private var pictureInPictureButton: some View {
        let palette = VideoPalette(theme: theme)

        return Button {
            togglePiP()
        } label: {
            Image(systemName: isPictureInPictureActive || isPictureInPictureStarting ? "pip.exit" : "pip.enter")
                .font(.du(.titleSmall))
                .foregroundColor(palette.inverseText)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!AVPictureInPictureController.isPictureInPictureSupported())
        .opacity(AVPictureInPictureController.isPictureInPictureSupported() ? 1 : 0.45)
    }

    private var fullscreenButton: some View {
        let palette = VideoPalette(theme: theme)

        return Button {
            toggleFullscreen()
        } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.du(.titleSmall))
                .foregroundColor(palette.inverseText)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func controlPill(icon: String, text: String) -> some View {
        let palette = VideoPalette(theme: theme)

        return HStack(spacing: DUSpacing.xs) {
            Image(systemName: icon)
                .font(.du(.body))

            if horizontalSizeClass != .compact {
                Text(text)
                    .font(.du(.body))
                    .lineLimit(1)
            }
        }
        .foregroundColor(palette.inverseText)
        .padding(.horizontal, DUSpacing.compact)
        .padding(.vertical, DUSpacing.base)
        .background(palette.mediaControlBackground)
        .overlay {
            RoundedRectangle(cornerRadius: DURadius.xs, style: .continuous)
                .stroke(palette.mediaControlBorder, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: DURadius.xs, style: .continuous))
    }

    private func configurePictureInPictureCallbacks() {
        presentationCoordinator.pictureInPictureCoordinator.onStateChange = { isActive in
            isPictureInPictureStarting = false
            isPictureInPictureActive = isActive
            if !isActive {
                showControls = true
                if shouldCleanupAfterPictureInPictureStops {
                    shouldCleanupAfterPictureInPictureStops = false
                    if presentationCoordinator.isRestoringFromPictureInPicture {
                        cleanupPlayer(
                            shouldResetOrientation: false,
                            shouldPausePlayer: false,
                            shouldClearRetainedPlayback: false
                        )
                    } else {
                        cleanupPlayer(shouldResetOrientation: true)
                    }
                }
            }
        }
        presentationCoordinator.pictureInPictureCoordinator.onRestoreInterface = { completionHandler in
            DispatchQueue.main.async {
                showControls = true
                enterFullscreenPlaybackMode()
                completionHandler(true)
            }
        }
        presentationCoordinator.pictureInPictureCoordinator.onFailure = {
            isPictureInPictureStarting = false
            isPictureInPictureActive = false
        }
    }

    private func setupPlayer(
        initialTime: Double? = nil,
        shouldAutoPlay: Bool = true
    ) {
        configureCRMAudioSessionForPiP()

        guard let source = preferredSource(for: currentQuality) else {
            return
        }

        let playerItem = AVPlayerItem(url: source.url)

        if let player {
            removeTimeObserver(from: player)
            player.replaceCurrentItem(with: playerItem)
            player.automaticallyWaitsToMinimizeStalling = true
        } else {
            let newPlayer = AVPlayer(playerItem: playerItem)
            newPlayer.automaticallyWaitsToMinimizeStalling = true
            player = newPlayer
        }

        currentQuality = source.quality
        currentTime = 0
        duration = 0

        setupTimeObserver()
        setupDefaultAudioTrack()
        setupDefaultSubtitle()

        if let initialTime,
           initialTime.isFinite,
           initialTime > 0 {
            seekTo(time: initialTime)
        }

        if shouldAutoPlay {
            player?.play()
        } else {
            player?.pause()
        }
        isPlaying = shouldAutoPlay
    }

    private func applyRetainedPlaybackSnapshot() {
        if let retainedPlaybackSession = presentationCoordinator.retainedPlaybackSession {
            playbackSession = retainedPlaybackSession
        }

        if let retainedCurrentQuality = presentationCoordinator.retainedCurrentQuality {
            currentQuality = retainedCurrentQuality
        }

        if let retainedSubtitleID = presentationCoordinator.retainedSubtitleID {
            currentSubtitle = playbackSession.episode.subtitleTracks.first(where: { $0.id == retainedSubtitleID })
        }

        if let retainedAudioTrackID = presentationCoordinator.retainedAudioTrackID {
            currentAudioTrack = playbackSession.episode.audioTracks.first(where: { $0.id == retainedAudioTrackID })
        }
    }

    private func restoreRetainedPlaybackIfNeeded() -> Bool {
        guard player == nil,
              let retainedPlayer = presentationCoordinator.retainedPlayer else {
            return false
        }

        applyRetainedPlaybackSnapshot()

        player = retainedPlayer
        retainedPlayer.automaticallyWaitsToMinimizeStalling = true

        let restoredTime = retainedPlayer.currentTime().seconds
        if presentationCoordinator.retainedPlaybackTime > 0,
           (!restoredTime.isFinite || abs(restoredTime - presentationCoordinator.retainedPlaybackTime) > 1) {
            let targetTime = CMTime(
                seconds: presentationCoordinator.retainedPlaybackTime,
                preferredTimescale: CMTimeScale(NSEC_PER_SEC)
            )
            retainedPlayer.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
            currentTime = presentationCoordinator.retainedPlaybackTime
        } else {
            currentTime = restoredTime.isFinite ? restoredTime : 0
        }

        if let itemDuration = retainedPlayer.currentItem?.duration.seconds, itemDuration.isFinite {
            duration = itemDuration
        }

        isPlaying = retainedPlayer.timeControlStatus != .paused
        setupTimeObserver()

        if let currentSubtitle, currentSubtitle.languageCode != "off" {
            loadSubtitle(currentSubtitle)
        } else {
            subtitleCues = []
            subtitleText = ""
        }

        return true
    }

    private func preferredSource(for quality: VideoQuality) -> VideoEpisodeResolution? {
        let episode = playbackSession.episode

        if let exact = episode.resolutions.first(where: { $0.quality == quality }) {
            return exact
        }

        let preferredOrder: [VideoQuality] = [.hd720, .hd1080, .sd480, .uhd4k, .auto]
        for item in preferredOrder {
            if let source = episode.resolutions.first(where: { $0.quality == item }) {
                return source
            }
        }

        return episode.resolutions.sorted { $0.quality.sortOrder < $1.quality.sortOrder }.first
    }

    private func setupDefaultAudioTrack() {
        let track = currentAudioTrack
            ?? playbackSession.episode.audioTracks.first(where: \.isDefault)
            ?? playbackSession.episode.audioTracks.first
        currentAudioTrack = track

        guard let track else {
            return
        }

        if track.isExternal {
            addExternalAudioTrack(track)
        } else {
            switchEmbeddedAudioTrack(to: track)
        }
    }

    private func setupDefaultSubtitle() {
        if let offSubtitle = playbackSession.episode.subtitleTracks.first(where: { $0.languageCode == "off" }) {
            currentSubtitle = offSubtitle
        } else if currentSubtitle == nil {
            currentSubtitle = playbackSession.episode.subtitleTracks.first
        }

        subtitleCues = []
        subtitleText = ""
    }

    private func setupTimeObserver() {
        guard let player else {
            return
        }

        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { time in
            guard !isSeeking else {
                return
            }

            currentTime = time.seconds

            if let itemDuration = player.currentItem?.duration.seconds, itemDuration.isFinite {
                duration = itemDuration
            }

            updateSubtitleText()
        }
    }

    private func cleanupPlayer(
        shouldResetOrientation: Bool,
        shouldPausePlayer: Bool = true,
        shouldClearRetainedPlayback: Bool = true
    ) {
        if let player {
            removeTimeObserver(from: player)
            if shouldPausePlayer {
                player.pause()
            }
        }
        self.player = nil
        pipController = nil
        playerLayer = nil
        isPictureInPictureActive = false
        isPictureInPictureStarting = false

        if shouldClearRetainedPlayback {
            presentationCoordinator.clearRetainedPlayback()
        }

        if shouldResetOrientation {
            resetOrientation()
        }
    }

    private func handlePlayerViewDisappear() {
        if shouldKeepPlaybackRunningForPictureInPicture {
            if let player {
                removeTimeObserver(from: player)
            }
            presentationCoordinator.retainPlayback(
                player: player,
                playbackSession: playbackSession,
                currentQuality: currentQuality,
                currentSubtitle: currentSubtitle,
                currentAudioTrack: currentAudioTrack,
                currentTime: currentTime,
                wasPlaying: isPlaying
            )
            shouldCleanupAfterPictureInPictureStops = true
            return
        }

        cleanupPlayer(shouldResetOrientation: true)
    }

    private var shouldKeepPlaybackRunningForPictureInPicture: Bool {
        isPictureInPictureActive
            || isPictureInPictureStarting
            || pipController?.isPictureInPictureActive == true
    }

    private func removeTimeObserver(from player: AVPlayer) {
        if let timeObserverToken {
            player.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
    }

    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showControls.toggle()
        }
    }

    private func togglePlayPause() {
        if isPlaying {
            player?.pause()
        } else {
            player?.play()
        }
        isPlaying.toggle()
    }

    private func seek(by seconds: Double) {
        guard let player else {
            return
        }

        let current = player.currentTime().seconds
        guard current.isFinite else {
            return
        }

        let totalDuration = player.currentItem?.duration.seconds ?? 0
        let maxTime = totalDuration.isFinite && totalDuration > 0
            ? totalDuration
            : Double.greatestFiniteMagnitude
        let newTime = max(0, min(current + seconds, maxTime))

        let targetTime = CMTime(seconds: newTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = newTime
    }

    private func seekTo(time: Double) {
        guard let player, time.isFinite else {
            return
        }

        let targetTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = time
    }

    private func switchQuality(to quality: VideoQuality) {
        guard quality != currentQuality,
              let source = playbackSession.episode.resolutions.first(where: { $0.quality == quality }) else {
            return
        }

        let savedTime = currentTime
        let wasPlaying = isPlaying
        let savedAudioTrack = currentAudioTrack

        let playerItem = AVPlayerItem(url: source.url)
        player?.replaceCurrentItem(with: playerItem)
        currentQuality = quality

        if let savedAudioTrack, savedAudioTrack.isExternal {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                addExternalAudioTrack(savedAudioTrack)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    seekTo(time: savedTime)
                    if wasPlaying {
                        player?.play()
                        isPlaying = true
                    }
                }
            }
        } else {
            seekTo(time: savedTime)
            if wasPlaying {
                player?.play()
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite else {
            return "00:00"
        }

        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }

        return String(format: "%02d:%02d", minutes, secs)
    }

    private func switchSubtitle(to subtitle: VideoSubtitleTrack) {
        currentSubtitle = subtitle

        if subtitle.languageCode == "off" {
            subtitleCues = []
            subtitleText = ""
            return
        }

        loadSubtitle(subtitle)
    }

    private func loadSubtitle(_ subtitle: VideoSubtitleTrack) {
        guard let url = subtitle.url else {
            subtitleCues = []
            subtitleText = ""
            return
        }

        let isSRT = url.absoluteString.lowercased().hasSuffix(".srt")

        DispatchQueue.global().async {
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                let cues = isSRT ? parseSRT(content) : parseVTT(content)
                DispatchQueue.main.async {
                    subtitleCues = cues
                }
            } catch {
                DispatchQueue.main.async {
                    subtitleCues = []
                    subtitleText = ""
                }
            }
        }
    }

    private func parseSRT(_ content: String) -> [CRMSubtitleCue] {
        var cues: [CRMSubtitleCue] = []
        let lines = content.components(separatedBy: .newlines)
        var index = 0

        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespaces)

            if Int(line) != nil {
                index += 1
                continue
            }

            if line.contains("-->") {
                let timePart = line.components(separatedBy: "-->")
                if timePart.count >= 2 {
                    let startTime = parseVTTTime(
                        timePart[0]
                            .trimmingCharacters(in: .whitespaces)
                            .replacingOccurrences(of: ",", with: ".")
                    )
                    let endTime = parseVTTTime(
                        timePart[1]
                            .trimmingCharacters(in: .whitespaces)
                            .replacingOccurrences(of: ",", with: ".")
                    )

                    var textLines: [String] = []
                    index += 1
                    while index < lines.count {
                        let textLine = lines[index].trimmingCharacters(in: .whitespaces)
                        if textLine.isEmpty {
                            break
                        }
                        textLines.append(textLine)
                        index += 1
                    }

                    if !textLines.isEmpty {
                        cues.append(
                            CRMSubtitleCue(
                                startTime: startTime,
                                endTime: endTime,
                                text: textLines.joined(separator: "\n")
                            )
                        )
                    }
                }
            }

            index += 1
        }

        return cues
    }

    private func parseVTT(_ content: String) -> [CRMSubtitleCue] {
        var cues: [CRMSubtitleCue] = []
        let lines = content.components(separatedBy: .newlines)
        var index = 0

        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespaces)

            if line.contains("-->") {
                let timePart = line.components(separatedBy: "-->")
                if timePart.count >= 2 {
                    let startTime = parseVTTTime(
                        timePart[0].trimmingCharacters(in: .whitespaces)
                    )
                    let endTimePart = timePart[1].trimmingCharacters(in: .whitespaces)
                    let endTime = parseVTTTime(
                        endTimePart.components(separatedBy: " ").first ?? endTimePart
                    )

                    var textLines: [String] = []
                    index += 1
                    while index < lines.count, !lines[index].trimmingCharacters(in: .whitespaces).isEmpty {
                        let textLine = lines[index]
                            .replacingOccurrences(
                                of: "<[^>]+>",
                                with: "",
                                options: .regularExpression
                            )
                            .trimmingCharacters(in: .whitespaces)
                        if !textLine.isEmpty {
                            textLines.append(textLine)
                        }
                        index += 1
                    }

                    if !textLines.isEmpty {
                        let text = textLines.joined(separator: "\n")
                        if cues.last?.text != text {
                            cues.append(
                                CRMSubtitleCue(
                                    startTime: startTime,
                                    endTime: endTime,
                                    text: text
                                )
                            )
                        }
                    }
                }
            }

            index += 1
        }

        return cues
    }

    private func parseVTTTime(_ timeString: String) -> Double {
        let parts = timeString.components(separatedBy: ":")
        var seconds: Double = 0

        if parts.count == 3 {
            seconds += (Double(parts[0]) ?? 0) * 3600
            seconds += (Double(parts[1]) ?? 0) * 60
            seconds += Double(parts[2].replacingOccurrences(of: ",", with: ".")) ?? 0
        } else if parts.count == 2 {
            seconds += (Double(parts[0]) ?? 0) * 60
            seconds += Double(parts[1].replacingOccurrences(of: ",", with: ".")) ?? 0
        }

        return seconds
    }

    private func updateSubtitleText() {
        guard !subtitleCues.isEmpty else {
            subtitleText = ""
            return
        }

        if let cue = subtitleCues.first(where: { currentTime >= $0.startTime && currentTime <= $0.endTime }) {
            subtitleText = cue.text
        } else {
            subtitleText = ""
        }
    }

    private func switchAudioTrack(to track: VideoAudioTrack) {
        guard track.id != currentAudioTrack?.id else {
            return
        }

        let savedTime = currentTime
        let wasPlaying = isPlaying

        if track.isExternal {
            addExternalAudioTrack(track)
            currentAudioTrack = track

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                seekTo(time: savedTime)
                if wasPlaying {
                    player?.play()
                    isPlaying = true
                }
            }
        } else {
            switchEmbeddedAudioTrack(to: track)
        }
    }

    private func addExternalAudioTrack(_ track: VideoAudioTrack) {
        guard let audioURL = track.url,
              let player,
              let currentItem = player.currentItem else {
            return
        }

        let composition = AVMutableComposition()
        let videoAsset = currentItem.asset
        let audioAsset = AVAsset(url: audioURL)

        let videoDuration = videoAsset.duration
        let timeRange = CMTimeRange(start: .zero, duration: videoDuration)

        if let videoTrack = videoAsset.tracks(withMediaType: .video).first,
           let compositionVideoTrack = composition.addMutableTrack(
               withMediaType: .video,
               preferredTrackID: kCMPersistentTrackID_Invalid
           ) {
            try? compositionVideoTrack.insertTimeRange(timeRange, of: videoTrack, at: .zero)
        }

        if let audioTrackAsset = audioAsset.tracks(withMediaType: .audio).first,
           let compositionAudioTrack = composition.addMutableTrack(
               withMediaType: .audio,
               preferredTrackID: kCMPersistentTrackID_Invalid
           ) {
            let audioDuration = audioAsset.duration
            let insertDuration = CMTimeMinimum(videoDuration, audioDuration)
            let audioTimeRange = CMTimeRange(start: .zero, duration: insertDuration)
            try? compositionAudioTrack.insertTimeRange(audioTimeRange, of: audioTrackAsset, at: .zero)
        }

        let newPlayerItem = AVPlayerItem(asset: composition)
        player.replaceCurrentItem(with: newPlayerItem)
    }

    private func switchEmbeddedAudioTrack(to track: VideoAudioTrack) {
        guard let playerItem = player?.currentItem,
              let group = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) else {
            currentAudioTrack = track
            return
        }

        let trackLanguage = track.languageCode.lowercased()
        let languagePrefix = trackLanguage.components(separatedBy: "-").first ?? trackLanguage
        let displayNames = [
            track.languageCode.lowercased(),
            languagePrefix,
            track.displayName.value(for: languageStore.currentLanguage).lowercased(),
            track.displayName.english.lowercased(),
            track.displayName.arabic.lowercased(),
        ]

        for option in group.options {
            let optionLanguage = option.locale?.identifier.lowercased() ?? ""
            let optionName = option.displayName.lowercased()

            if optionLanguage.contains(trackLanguage)
                || optionLanguage.contains(languagePrefix)
                || displayNames.contains(where: { !$0.isEmpty && optionName.contains($0) })
                || (languagePrefix == "ja" && (optionName.contains("japan") || optionName.contains("日本")))
                || (languagePrefix == "en" && (optionName.contains("english") || optionName.contains("eng"))) {
                playerItem.select(option, in: group)
                currentAudioTrack = track
                return
            }
        }

        if let trackIndex = playbackSession.episode.audioTracks.firstIndex(where: { $0.id == track.id }),
           trackIndex < group.options.count {
            playerItem.select(group.options[trackIndex], in: group)
            currentAudioTrack = track
            return
        }

        currentAudioTrack = track
    }

    private func setupPiP(with layer: AVPlayerLayer) {
        guard pipController == nil else {
            return
        }

        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            return
        }

        guard layer.player != nil else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                setupPiP(with: layer)
            }
            return
        }

        guard let controller = AVPictureInPictureController(playerLayer: layer) else {
            return
        }
        #if canImport(UIKit)
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        #endif
        controller.delegate = presentationCoordinator.pictureInPictureCoordinator
        isPictureInPictureActive = controller.isPictureInPictureActive
        pipController = controller
    }

    private func togglePiP() {
        guard let pipController = preparePiPController() else {
            return
        }

        if pipController.isPictureInPictureActive {
            isPictureInPictureStarting = false
            pipController.stopPictureInPicture()
        } else {
            isPictureInPictureStarting = true
            pipController.startPictureInPicture()
        }
    }

    private func preparePiPController() -> AVPictureInPictureController? {
        if let pipController {
            return pipController
        }

        guard let playerLayer else {
            return nil
        }

        setupPiP(with: playerLayer)
        return pipController
    }

    private func toggleFullscreen() {
        #if canImport(UIKit)
        if #available(iOS 16.0, *),
           let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            let currentOrientation = windowScene.interfaceOrientation
            if currentOrientation.isLandscape {
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
            } else {
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
            }
        }
        #endif
    }

    private func enterFullscreenPlaybackMode() {
        #if canImport(UIKit)
        if #available(iOS 16.0, *),
           let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           !windowScene.interfaceOrientation.isLandscape {
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
        }
        #endif
    }

    private func resetOrientation() {
        #if canImport(UIKit)
        if #available(iOS 16.0, *),
           let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           windowScene.interfaceOrientation.isLandscape {
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
        }
        #endif
    }

    private func switchEpisode(to episode: VideoEpisode) async {
        guard episode.id != playbackSession.episode.id else {
            return
        }

        isSwitchingEpisode = true
        defer {
            isSwitchingEpisode = false
        }

        do {
            let nextSession = try await videoService.requestPlaybackSession(
                videoID: detail.content.id,
                episodeID: episode.id,
                preferredQuality: currentQuality,
                session: sessionInfo
            )

            playbackSession = nextSession
            currentQuality = nextSession.episode.resolutions.first?.quality ?? currentQuality
            currentSubtitle = nextSession.episode.subtitleTracks.first(where: { $0.languageCode == "off" })
                ?? nextSession.episode.subtitleTracks.first
            currentAudioTrack = nextSession.episode.audioTracks.first(where: \.isDefault)
                ?? nextSession.episode.audioTracks.first
            subtitleCues = []
            subtitleText = ""
            setupPlayer()
        } catch {
            // Keep current playback when switching episode fails.
        }
    }

    private func localizedFallback(_ zh: String, _ en: String, _ ar: String) -> String {
        VideoLocalizedString(zh, en, ar)
            .value(for: languageStore.currentLanguage)
    }
}

private struct CRMSubtitleCue {
    let startTime: Double
    let endTime: Double
    let text: String
}

@MainActor
final class CRMVideoPlayerPresentationCoordinator: ObservableObject {
    @Published var isPlayerPresented = false
    @Published var shouldForceFullscreenOnNextAppear = false

    var isRestoringFromPictureInPicture = false
    var retainedPlayer: AVPlayer?
    var retainedPlaybackSession: VideoPlaybackSession?
    var retainedCurrentQuality: VideoQuality?
    var retainedSubtitleID: String?
    var retainedAudioTrackID: String?
    var retainedPlaybackTime: Double = 0
    var retainedWasPlaying = false

    let pictureInPictureCoordinator = CRMVideoPictureInPictureCoordinator()

    init() {
	        pictureInPictureCoordinator.onRestorePresentation = { [weak self] in
	            guard let self else {
	                return
	            }
	
	            self.isRestoringFromPictureInPicture = true
	            self.shouldForceFullscreenOnNextAppear = true
	            self.isPlayerPresented = true
	        }
	    }

    func retainPlayback(
        player: AVPlayer?,
        playbackSession: VideoPlaybackSession,
        currentQuality: VideoQuality,
        currentSubtitle: VideoSubtitleTrack?,
        currentAudioTrack: VideoAudioTrack?,
        currentTime: Double,
        wasPlaying: Bool
    ) {
        retainedPlayer = player
        retainedPlaybackSession = playbackSession
        retainedCurrentQuality = currentQuality
        retainedSubtitleID = currentSubtitle?.id
        retainedAudioTrackID = currentAudioTrack?.id
        retainedPlaybackTime = currentTime
        retainedWasPlaying = wasPlaying
    }

    func clearRetainedPlayback() {
        retainedPlayer = nil
        retainedPlaybackSession = nil
        retainedCurrentQuality = nil
        retainedSubtitleID = nil
        retainedAudioTrackID = nil
        retainedPlaybackTime = 0
        retainedWasPlaying = false
        isRestoringFromPictureInPicture = false
    }

    func completePictureInPictureRestoreIfNeeded() {
        pictureInPictureCoordinator.completePendingRestoreIfNeeded(success: true)
        isRestoringFromPictureInPicture = false
    }
}

final class CRMVideoPictureInPictureCoordinator: NSObject, ObservableObject, AVPictureInPictureControllerDelegate {
    typealias RestoreInterfaceHandler = (@escaping (Bool) -> Void) -> Void

    var onStateChange: ((Bool) -> Void)?
    var onRestorePresentation: (() -> Void)?
    var onRestoreInterface: RestoreInterfaceHandler?
    var onFailure: (() -> Void)?
    private var pendingRestoreCompletionHandler: ((Bool) -> Void)?

    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        DispatchQueue.main.async {
            self.onStateChange?(true)
        }
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        DispatchQueue.main.async {
            self.onStateChange?(false)
        }
    }

    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        DispatchQueue.main.async {
            self.onFailure?()
            self.onStateChange?(false)
        }
    }

    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        DispatchQueue.main.async {
            self.onRestorePresentation?()
            if let onRestoreInterface = self.onRestoreInterface {
                onRestoreInterface(completionHandler)
            } else {
                self.pendingRestoreCompletionHandler = completionHandler
            }
        }
    }

    func completePendingRestoreIfNeeded(success: Bool) {
        guard let pendingRestoreCompletionHandler else {
            return
        }

        self.pendingRestoreCompletionHandler = nil
        pendingRestoreCompletionHandler(success)
    }
}

private extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

private extension VideoAudioTrack {
    var isExternal: Bool {
        url != nil
    }
}
