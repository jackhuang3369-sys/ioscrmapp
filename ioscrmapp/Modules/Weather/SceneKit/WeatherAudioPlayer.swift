import AVFoundation
import UIKit

final class WeatherAudioPlayer {

    static let shared = WeatherAudioPlayer()

    private let audioQueue = DispatchQueue(label: "com.weather.audio.burst", qos: .default)
    private var oneshotPool: [String: [AVAudioPlayer]] = [:]
    private var sunTapPlayer: AVAudioPlayer?
    private var sunTapClickCount: Int = 0
    private var sunTapLastCallTime: TimeInterval = 0
    private var orbitCheckpointIndex: Int = 0

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

    func playSunDetailEnter() {
        playOneshot("sun-detail-enter", volume: 1.0)
    }

    func playSunDetailExit() {
        playOneshot("sun-detail-exit", volume: 1.0)
    }

    func playTimelineScrollTick() {
        playOneshot("ui-time-scroll-click-1", volume: 0.22, maxConcurrentPlayers: 4)
    }

    func playDaySelect() {
        playOneshot("ui-day-select-1", volume: 0.24)
    }

    func prewarm(_ names: [String], maxConcurrentPlayers: Int = 1) {
        audioQueue.async { [weak self] in
            guard let self else { return }
            names.forEach { name in
                self.prewarmOneshotLocked(name, maxConcurrentPlayers: maxConcurrentPlayers)
            }
        }
    }

    func resetOrbitCheckpointSequence() {
        audioQueue.async { [weak self] in
            self?.orbitCheckpointIndex = 0
        }
    }

    func playOrbitCheckpoint() {
        audioQueue.async { [weak self] in
            guard let self else { return }
            let name = WeatherOrbitAudioRuntimeCore.checkpointName(
                at: self.orbitCheckpointIndex
            )
            self.orbitCheckpointIndex = WeatherOrbitAudioRuntimeCore.nextIndex(
                after: self.orbitCheckpointIndex
            )
            self.playOneshotLocked(
                name,
                volume: WeatherOrbitAudioRuntimeCore.checkpointVolume,
                maxConcurrentPlayers: 4
            )
        }
    }

    func playOrbitWhoosh() {
        playOneshot(
            WeatherOrbitAudioRuntimeCore.whooshName,
            volume: WeatherOrbitAudioRuntimeCore.whooshVolume,
            maxConcurrentPlayers: 3
        )
    }

    func playSunTapBurst() {
        audioQueue.async { [weak self] in
            guard let self else { return }
            let now = CACurrentMediaTime()
            self.sunTapClickCount = WeatherSunTapAudioRuntimeCore.nextClickCount(
                previousCount: self.sunTapClickCount,
                lastTapTime: self.sunTapLastCallTime,
                now: now
            )
            self.sunTapLastCallTime = now

            let index = Int.random(in: WeatherSunTapAudioRuntimeCore.sfxIndexRange)
            let name = WeatherSunTapAudioRuntimeCore.sfxName(for: index)
            let volume = WeatherSunTapAudioRuntimeCore.volume(forClickCount: self.sunTapClickCount)
            self.playSunTapOneshot(name, volume: volume)
        }
    }

    private func playOneshot(_ name: String, volume: Float, maxConcurrentPlayers: Int = 2) {
        audioQueue.async { [weak self] in
            self?.playOneshotLocked(name, volume: volume, maxConcurrentPlayers: maxConcurrentPlayers)
        }
    }

    private func playOneshotLocked(_ name: String, volume: Float, maxConcurrentPlayers: Int = 2) {
        var pool = oneshotPool[name] ?? []
        let reusable = pool.first { !$0.isPlaying }
        let player: AVAudioPlayer

        if let reusable {
            player = reusable
            player.currentTime = 0
        } else {
            guard pool.count < maxConcurrentPlayers else {
                return
            }
            guard let url = audioURL(name),
                  let created = try? AVAudioPlayer(contentsOf: url) else { return }
            created.prepareToPlay()
            pool.append(created)
            oneshotPool[name] = pool
            player = created
        }

        player.volume = volume
        player.play()
    }

    private func prewarmOneshotLocked(_ name: String, maxConcurrentPlayers: Int) {
        var pool = oneshotPool[name] ?? []
        if !pool.isEmpty || pool.count >= maxConcurrentPlayers {
            return
        }

        guard let url = audioURL(name),
              let created = try? AVAudioPlayer(contentsOf: url) else { return }
        created.prepareToPlay()
        pool.append(created)
        oneshotPool[name] = pool
    }

    private func playSunTapOneshot(_ name: String, volume: Float) {
        guard let url = audioURL(name) else { return }

        if let current = sunTapPlayer, current.isPlaying {
            current.stop()
            current.currentTime = 0
        }

        let player: AVAudioPlayer
        if let current = sunTapPlayer, current.url == url {
            player = current
            player.currentTime = 0
        } else {
            guard let created = try? AVAudioPlayer(contentsOf: url) else { return }
            created.prepareToPlay()
            sunTapPlayer = created
            player = created
        }

        player.volume = volume
        player.play()
    }

    private func audioURL(_ name: String) -> URL? {
        WeatherSunTapAudioRuntimeCore.audioURL(name: name, bundle: .main, fileManager: .default)
    }
}

private enum WeatherOrbitAudioRuntimeCore {
    static let checkpointNames: [String] = [
        "remote_1",
        "remote_2",
        "remote_3",
        "remote_4",
        "remote_5",
        "remote_6"
    ]
    static let checkpointVolume: Float = 0.52
    static let whooshName = "spin-slow-4"
    static let whooshVolume: Float = 0.30

    static func checkpointName(at index: Int) -> String {
        let safeIndex = positiveModulo(index, checkpointNames.count)
        return checkpointNames[safeIndex]
    }

    static func nextIndex(after index: Int) -> Int {
        positiveModulo(index + 1, checkpointNames.count)
    }

    private static func positiveModulo(_ value: Int, _ divisor: Int) -> Int {
        let remainder = value % divisor
        return remainder >= 0 ? remainder : remainder + divisor
    }
}

private enum WeatherSunTapAudioRuntimeCore {
    static let resetInterval: TimeInterval = 0.5
    static let brightVolume: Float = 0.36
    static let mediumVolume: Float = 0.28
    static let softVolume: Float = 0.20
    static let sfxIndexRange: ClosedRange<Int> = 1...7

    static func sfxName(for index: Int) -> String {
        let clamped = min(max(index, sfxIndexRange.lowerBound), sfxIndexRange.upperBound)
        return String(format: "sfx_%03d", clamped)
    }

    static func volume(forClickCount count: Int) -> Float {
        switch count {
        case 1...2:
            return brightVolume
        case 3...4:
            return mediumVolume
        default:
            return softVolume
        }
    }

    static func nextClickCount(previousCount: Int, lastTapTime: TimeInterval, now: TimeInterval) -> Int {
        guard lastTapTime > 0 else { return 1 }
        if now - lastTapTime > resetInterval {
            return 1
        }
        return previousCount + 1
    }

    static func audioURL(name: String, bundle: Bundle, fileManager: FileManager) -> URL? {
        let folder = "WeatherData/Audio"
        for ext in ["m4a", "mp3", "wav"] {
            let direct = bundle.bundleURL.appendingPathComponent("\(folder)/\(name).\(ext)")
            if fileManager.fileExists(atPath: direct.path) {
                return direct
            }
            if let bundled = bundle.url(forResource: name, withExtension: ext, subdirectory: folder) {
                return bundled
            }
        }
        return nil
    }
}
