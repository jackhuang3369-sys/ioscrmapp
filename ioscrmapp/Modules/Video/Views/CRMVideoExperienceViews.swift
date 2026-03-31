import AVFoundation
import AVKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct CRMVideoDetailContent: View {
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
            .padding(.bottom, 40)
        }
        .background(Color(.systemBackground))
        .crmApplyInlineNavigationTitleDisplayMode()
    }

    private var headerSection: some View {
        ZStack(alignment: .bottomLeading) {
            VideoImageView(
                image: detail.heroImage,
                cornerRadius: 0,
                contentMode: .fill
            )
            .frame(height: 250)
            .clipped()
            .blur(radius: 20)
            .overlay(Color.black.opacity(0.32))

            HStack(alignment: .bottom, spacing: 16) {
                VideoImageView(
                    image: detail.content.posterImage,
                    cornerRadius: 10,
                    contentMode: .fill
                )
                .frame(width: 120, height: 170)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: .black.opacity(0.22), radius: 10, x: 0, y: 8)

                VStack(alignment: .leading, spacing: 8) {
                    Text(detail.content.title.value(for: languageStore.currentLanguage))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .lineLimit(2)

                    if let ratingText = detail.content.ratingText {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)

                            Text(ratingText)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        .font(.subheadline)
                        .environment(\.layoutDirection, .leftToRight)
                    }

                    if !detail.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(detail.tags.prefix(3)) { tag in
                                    Text(tag.title.value(for: languageStore.currentLanguage))
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.92))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.white.opacity(0.2))
                                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                }
                            }
                        }
                    }

                    if let selectedEpisode {
                        Text(selectedEpisode.title.value(for: languageStore.currentLanguage))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.82))
                            .lineLimit(1)
                    }

                    Button(action: onPlay) {
                        HStack(spacing: 8) {
                            if isRequestingPlayback {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "play.fill")
                            }

                            Text(localized("video.detail.playNow"))
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(detail.isPlayable ? Color.blue : Color.gray.opacity(0.45))
                        .clipShape(Capsule())
                    }
                    .disabled(!detail.isPlayable || selectedEpisode == nil || isRequestingPlayback)

                    if !detail.isPlayable {
                        Text(
                            detail.content.availabilityMessage?.value(for: languageStore.currentLanguage)
                                ?? localized("video.unavailable.noSource.title")
                        )
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.88))
                        .lineLimit(2)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding()
        }
    }

    private var infoSection: some View {
        HStack(spacing: 16) {
            ForEach(detail.stats) { stat in
                VStack(spacing: 6) {
                    Image(systemName: stat.systemImage)
                        .font(.title3)
                        .foregroundColor(color(for: stat.id))

                    Text(stat.value)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .environment(\.layoutDirection, .leftToRight)

                    Text(localized(stat.titleKey))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localized("video.detail.synopsis"))
                .font(.headline)

            Text(detail.synopsis.value(for: languageStore.currentLanguage))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(isDescriptionExpanded ? nil : 3)

            Button(action: toggleDescription) {
                Text(expandActionTitle)
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal)
    }

    private var episodeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(localized("video.detail.episodes")) (\(episodes.count))")
                .font(.headline)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(episodes) { episode in
                        Button {
                            onSelectEpisode(episode)
                        } label: {
                            VStack(spacing: 6) {
                                ZStack {
                                    VideoImageView(
                                        image: episode.thumbnailImage,
                                        cornerRadius: 8,
                                        contentMode: .fill
                                    )
                                    .frame(width: 96, height: 64)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                                    Color.black.opacity(0.22)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                                    Image(systemName: "play.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(
                                            selectedEpisodeID == episode.id ? Color.blue : Color.clear,
                                            lineWidth: 2
                                        )
                                )

                                Text(episode.title.value(for: languageStore.currentLanguage))
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)

                                Text(formattedDuration(episode.durationSeconds))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
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
        VStack(alignment: .leading, spacing: 12) {
            Text(localized("video.detail.cast"))
                .font(.headline)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(detail.cast) { member in
                        VStack(spacing: 8) {
                            if let avatarImage = member.avatarImage {
                                VideoImageView(
                                    image: avatarImage,
                                    cornerRadius: 30,
                                    contentMode: .fill
                                )
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color.gray.opacity(0.24))
                                    .frame(width: 60, height: 60)
                                    .overlay {
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.gray)
                                    }
                            }

                            Text(member.name)
                                .font(.caption)
                                .fontWeight(.medium)
                                .lineLimit(1)

                            if let role = member.role {
                                Text(role.value(for: languageStore.currentLanguage))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
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
        VStack(alignment: .leading, spacing: 12) {
            Text(localized("video.detail.related"))
                .font(.headline)
                .padding(.horizontal)

            if detail.related.isEmpty {
                Text(localized("video.state.error.subtitle"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            } else {
                VStack(spacing: 12) {
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
        switch statID {
        case "views":
            return .blue
        case "released":
            return .green
        case "episodes":
            return .orange
        case "duration":
            return .purple
        default:
            return .blue
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
    let content: VideoContentSummary
    let typeTitle: String
    let language: AppLanguage

    var body: some View {
        HStack(spacing: 12) {
            VideoImageView(
                image: content.posterImage,
                cornerRadius: 6,
                contentMode: .fill
            )
            .frame(width: 100, height: 70)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(content.title.value(for: language))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(2)

                HStack {
                    if let ratingText = content.ratingText {
                        Label(ratingText, systemImage: "star.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .environment(\.layoutDirection, .leftToRight)
                    }

                    Text(typeTitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }
}

struct CRMVideoPlayExperience: View {
    @Environment(\.dismiss) private var dismiss
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

    init(
        detail: VideoDetailSnapshot,
        initialSession: VideoPlaybackSession,
        sessionInfo: CustSubInfo,
        videoService: any VideoServicing
    ) {
        self.detail = detail
        self.sessionInfo = sessionInfo
        self.videoService = videoService
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
        GeometryReader { _ in
            ZStack {
                Color.black
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
                        .tint(.white)
                }

                if !subtitleText.isEmpty {
                    VStack {
                        Spacer()

                        Text(subtitleText)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(4)
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
            setupPlayer()
        }
        .onDisappear {
            cleanupPlayer(shouldResetOrientation: true)
        }
    }

    private var controlOverlay: some View {
        VStack {
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
        .background(Color.black.opacity(0.4).ignoresSafeArea())
        .transition(.opacity)
    }

    private var topBar: some View {
        HStack {
            CRMBackButton()

            Spacer()

            VStack(spacing: 2) {
                Text(playbackSession.mediaTitle.value(for: languageStore.currentLanguage))
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(playbackSession.episode.title.value(for: languageStore.currentLanguage))
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
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
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Button(action: {}) {
                    Image(systemName: "ellipsis")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var centerControls: some View {
        HStack(spacing: 60) {
            Button {
                seek(by: -10)
            } label: {
                Image(systemName: "gobackward.10")
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                togglePlayPause()
            } label: {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.white)
                    .frame(width: 80, height: 80)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                seek(by: 10)
            } label: {
                Image(systemName: "goforward.10")
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Text(formatTime(currentTime))
                    .font(.caption)
                    .foregroundColor(.white)
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
                .tint(.white)

                Text(formatTime(duration))
                    .font(.caption)
                    .foregroundColor(.white)
                    .monospacedDigit()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
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

                    Button {
                        togglePiP()
                    } label: {
                        Image(systemName: pipController?.isPictureInPictureActive == true ? "pip.exit" : "pip.enter")
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        toggleFullscreen()
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            if isSwitchingEpisode {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(.white)

                    Text(languageStore.string("video.player.loading"))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.86))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func controlPill(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.body)

            if horizontalSizeClass != .compact {
                Text(text)
                    .lineLimit(1)
            }
        }
        .font(.subheadline)
        .foregroundColor(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func setupPlayer() {
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

        player?.play()
        isPlaying = true
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

    private func cleanupPlayer(shouldResetOrientation: Bool) {
        if let player {
            removeTimeObserver(from: player)
            player.pause()
        }
        self.player = nil
        pipController = nil

        if shouldResetOrientation {
            resetOrientation()
        }
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
            track.displayName.value(for: languageStore.currentLanguage).lowercased(),
            track.displayName.english.lowercased(),
        ]

        for option in group.options {
            let optionLanguage = option.locale?.identifier.lowercased() ?? ""
            let optionName = option.displayName.lowercased()

            if optionLanguage.contains(trackLanguage)
                || optionLanguage.contains(languagePrefix)
                || displayNames.contains(where: { !$0.isEmpty && optionName.contains($0) }) {
                playerItem.select(option, in: group)
                currentAudioTrack = track
                return
            }
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
        pipController = controller
    }

    private func togglePiP() {
        guard let pipController else {
            return
        }

        if pipController.isPictureInPictureActive {
            pipController.stopPictureInPicture()
        } else {
            pipController.startPictureInPicture()
        }
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
