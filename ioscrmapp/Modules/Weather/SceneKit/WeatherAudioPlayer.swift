import AVFoundation
import UIKit

final class WeatherAudioPlayer {

    static let shared = WeatherAudioPlayer()

    private let audioQueue = DispatchQueue(label: "WeatherAudioPlayer.audioQueue")
    private var oneshotPool: [String: [AVAudioPlayer]] = [:]
    private var timelineTickPlayers: [AVAudioPlayer] = []
    private var timelineTickPlayerIndex = 0

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        timelineTickPlayers = makePlayers(name: "ui-time-scroll-click-1", count: 6)
    }

    func playShapeTap() {
        audioQueue.async { [self] in
            playOneshotNow("shape-tap-1", volume: 0.35)
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

    func playSpinLoop(fast: Bool) {
        audioQueue.async { [self] in
            playOneshotNow(fast ? "spin-fast-4" : "spin-slow-4", volume: 0.26)
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
        let direct = Bundle.main.bundleURL.appendingPathComponent("WeatherData/Audio/\(name).m4a")
        if FileManager.default.fileExists(atPath: direct.path) {
            return direct
        }
        return Bundle.main.url(forResource: name, withExtension: "m4a", subdirectory: "WeatherData/Audio")
    }
}
