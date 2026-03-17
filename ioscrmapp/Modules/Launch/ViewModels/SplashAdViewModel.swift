import AVFoundation
import Foundation

@MainActor
final class SplashAdViewModel: ObservableObject {
    @Published private(set) var isLoading = true
    @Published private(set) var isSkipEnabled = false
    @Published private(set) var isMuted = true
    @Published private(set) var progress: Double = 0
    @Published private(set) var buttonText: LocalizedTextValue = .key("splash.skip.compactCountdown", arguments: ["3"])
    @Published private(set) var failureMessage: LocalizedTextValue?

    let player = AVPlayer()

    private let playableAd: SplashAdPlayable
    private let onFinish: (SplashAdFinishReason) -> Void

    private var itemStatusObservation: NSKeyValueObservation?
    private var playbackEndObserver: NSObjectProtocol?
    private var timeObserverToken: Any?
    private var timeoutTask: Task<Void, Never>?
    private var completionTask: Task<Void, Never>?
    private var hasStarted = false
    private var hasFinished = false
    private var playbackDuration: Double = 0

    init(
        playableAd: SplashAdPlayable,
        onFinish: @escaping (SplashAdFinishReason) -> Void
    ) {
        self.playableAd = playableAd
        self.onFinish = onFinish
    }

    var audioButtonText: LocalizedTextValue {
        isMuted ? .key("splash.audio.unmute") : .key("splash.audio.mute")
    }

    var audioButtonSystemImageName: String {
        isMuted ? "speaker.wave.2.fill" : "speaker.slash.fill"
    }

    func startIfNeeded() {
        guard !hasStarted else {
            return
        }

        hasStarted = true
        player.isMuted = isMuted
        player.actionAtItemEnd = .pause

        let playerItem = AVPlayerItem(url: playableAd.fileURL)
        player.replaceCurrentItem(with: playerItem)
        observe(playerItem)

        timeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                self?.handleLoadFailureIfNeeded()
            }
        }
    }

    func skipIfAvailable() {
        guard isSkipEnabled else {
            return
        }

        finish(.skipped)
    }

    func toggleMuted() {
        isMuted.toggle()
        player.isMuted = isMuted
    }

    func stop() {
        timeoutTask?.cancel()
        completionTask?.cancel()
        player.pause()
        tearDownObservers()
    }

    private func observe(_ playerItem: AVPlayerItem) {
        itemStatusObservation = playerItem.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            Task { @MainActor in
                self?.handleStatusUpdate(for: item)
            }
        }

        playbackEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.finish(.playbackCompleted)
            }
        }
    }

    private func handleStatusUpdate(for item: AVPlayerItem) {
        guard !hasFinished else {
            return
        }

        switch item.status {
        case .readyToPlay:
            timeoutTask?.cancel()
            completionTask?.cancel()
            isLoading = false
            failureMessage = nil
            playbackDuration = resolvedPlaybackDuration(for: item)
            player.play()
            installTimeObserver()
        case .failed:
            handleLoadFailureIfNeeded()
        case .unknown:
            break
        @unknown default:
            handleLoadFailureIfNeeded()
        }
    }

    private func installTimeObserver() {
        guard timeObserverToken == nil else {
            return
        }

        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                self?.handlePlaybackTick(seconds: time.seconds)
            }
        }
    }

    private func handlePlaybackTick(seconds: Double) {
        guard seconds.isFinite, seconds >= 0, !hasFinished else {
            return
        }

        if playbackDuration <= 0, let currentItem = player.currentItem {
            playbackDuration = resolvedPlaybackDuration(for: currentItem)
        }

        if playbackDuration > 0 {
            progress = min(max(seconds / playbackDuration, 0), 1)
            buttonText = seconds >= 3
                ? .key("splash.skip.ready")
                : .key("splash.skip.compactCountdown", arguments: ["\(max(1, Int(ceil(3 - seconds))))"])
        } else {
            progress = 0
            buttonText = seconds >= 3
                ? .key("splash.skip.ready")
                : .key("splash.skip.compactCountdown", arguments: ["\(max(1, Int(ceil(3 - seconds))))"])
        }

        isSkipEnabled = seconds >= 3
    }

    private func resolvedPlaybackDuration(for item: AVPlayerItem) -> Double {
        let itemDuration = item.duration.seconds
        if itemDuration.isFinite, itemDuration > 0 {
            return itemDuration
        }

        let assetDuration = item.asset.duration.seconds
        if assetDuration.isFinite, assetDuration > 0 {
            return assetDuration
        }

        return 0
    }

    private func handleLoadFailureIfNeeded() {
        guard !hasFinished else {
            return
        }
        if let currentItem = player.currentItem, currentItem.status == .readyToPlay {
            completionTask?.cancel()
            isLoading = false
            failureMessage = nil
            return
        }
        if player.currentTime().seconds > 0 {
            completionTask?.cancel()
            isLoading = false
            failureMessage = nil
            return
        }

        isLoading = false
        failureMessage = .key("splash.loading.failed")
        completionTask?.cancel()
        completionTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000)
            await MainActor.run {
                self?.finish(.loadingFailed)
            }
        }
    }

    private func finish(_ reason: SplashAdFinishReason) {
        guard !hasFinished else {
            return
        }

        hasFinished = true
        timeoutTask?.cancel()
        completionTask?.cancel()
        player.pause()
        tearDownObservers()
        onFinish(reason)
    }

    private func tearDownObservers() {
        timeoutTask?.cancel()
        completionTask?.cancel()

        if let playbackEndObserver {
            NotificationCenter.default.removeObserver(playbackEndObserver)
            self.playbackEndObserver = nil
        }

        itemStatusObservation = nil

        if let timeObserverToken {
            player.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
    }
}
