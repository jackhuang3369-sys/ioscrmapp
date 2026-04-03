import AVFoundation
import UIKit

final class WeatherAudioPlayer {

    static let shared = WeatherAudioPlayer()

    private var oneshotPool: [String: [AVAudioPlayer]] = [:]

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func playShapeTap() {
        playOneshot("shape-tap-1", volume: 0.35)
    }

    func playSpinLoop(fast: Bool) {
        playOneshot(fast ? "spin-fast-4" : "spin-slow-4", volume: 0.26)
    }

    func playDetailedEnter() {
        playOneshot("menu-open-1", volume: 0.40)
    }

    private func playOneshot(_ name: String, volume: Float) {
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

    private func audioURL(_ name: String) -> URL? {
        let direct = Bundle.main.bundleURL.appendingPathComponent("WeatherData/Audio/\(name).m4a")
        if FileManager.default.fileExists(atPath: direct.path) {
            return direct
        }
        return Bundle.main.url(forResource: name, withExtension: "m4a", subdirectory: "WeatherData/Audio")
    }
}
