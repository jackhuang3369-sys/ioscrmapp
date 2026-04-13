import AVFoundation
import UIKit

final class WeatherAudioPlayer {

    static let shared = WeatherAudioPlayer()

    private struct WeatherSpinSoundProfile {
        let audioName: String
        let volume: Float

        static let `default`: [WeatherSpinSoundTier: WeatherSpinSoundProfile] = [
            .slow: .init(audioName: "spin-slow-4", volume: 0.24),
            .medium: .init(audioName: "spin-fast-5", volume: 0.26),
            .fast: .init(audioName: "spin-fast-4", volume: 0.28)
        ]
    }

    private let shapeTapVariants = ["shape-tap-1", "shape-tap-7"]
    private let detailSunTapVariants = [
        "sfx_001",
        "sfx_002",
        "sfx_003",
        "sfx_004",
        "sfx_005",
        "sfx_006",
        "sfx_007"
    ]
    private let audioQueue = DispatchQueue(label: "WeatherAudioPlayer.audioQueue")
    private let spinSoundProfiles: [WeatherSpinSoundTier: WeatherSpinSoundProfile]
    private var oneshotPool: [String: [AVAudioPlayer]] = [:]
    private var timelineTickPlayers: [AVAudioPlayer] = []
    private var timelineTickPlayerIndex = 0

    private init(spinSoundProfiles: [WeatherSpinSoundTier: WeatherSpinSoundProfile] = WeatherSpinSoundProfile.default) {
        self.spinSoundProfiles = spinSoundProfiles
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        timelineTickPlayers = makePlayers(name: "ui-time-scroll-click-1", count: 6)
    }

    func playShapeTap() {
        audioQueue.async { [self] in
            let soundName = shapeTapVariants.randomElement() ?? "shape-tap-1"
            playOneshotNow(soundName, volume: 0.35)
        }
    }

    func playDetailSunTap() {
        audioQueue.async { [self] in
            let soundName = detailSunTapVariants.randomElement() ?? "sfx_001"
            playOneshotNow(soundName, volume: 0.35)
        }
    }

    func playTimelineScrollTick() {
        audioQueue.async { [self] in
            guard !timelineTickPlayers.isEmpty else {
                playOneshotNow("ui-time-scroll-click-1", volume: 0.24)
                return
            }

            let player = timelineTickPlayers[timelineTickPlayerIndex]
            timelineTickPlayerIndex = (timelineTickPlayerIndex + 1) % timelineTickPlayers.count
            player.currentTime = 0
            player.volume = 0.24
            player.play()
        }
    }

    func playSpinLoop(tier: WeatherSpinSoundTier) {
        audioQueue.async { [self] in
            guard let profile = spinSoundProfiles[tier] else { return }
            playOneshotNow(profile.audioName, volume: profile.volume)
        }
    }

    func playDetailedEnter() {
        audioQueue.async { [self] in
            playOneshotNow("menu-open-1", volume: 0.40)
        }
    }

    private func playOneshotNow(_ name: String, volume: Float) {
        var pool = oneshotPool[name] ?? []
        let reusable = pool.first { !$0.isPlaying }
        let player: AVAudioPlayer

        if let reusable {
            player = reusable
            player.currentTime = 0
        } else {
            guard let url = audioURL(name),
                  let created = try? AVAudioPlayer(contentsOf: url) else { return }
            created.prepareToPlay()
            pool.append(created)
            if pool.count > 2 {
                pool.removeFirst()
            }
            oneshotPool[name] = pool
            player = created
        }

        player.volume = volume
        player.play()
    }

    private func makePlayers(name: String, count: Int) -> [AVAudioPlayer] {
        guard let url = audioURL(name) else { return [] }

        return (0..<count).compactMap { _ in
            guard let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
            player.prepareToPlay()
            return player
        }
    }

    private func audioURL(_ name: String) -> URL? {
        for fileExtension in ["m4a", "mp3"] {
            let direct = Bundle.main.bundleURL.appendingPathComponent("WeatherData/Audio/\(name).\(fileExtension)")
            if FileManager.default.fileExists(atPath: direct.path) {
                return direct
            }
            if let bundled = Bundle.main.url(
                forResource: name,
                withExtension: fileExtension,
                subdirectory: "WeatherData/Audio"
            ) {
                return bundled
            }
        }
        return nil
    }
}
