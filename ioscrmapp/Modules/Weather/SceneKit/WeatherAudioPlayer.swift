import AVFoundation
import UIKit

// MARK: - WeatherAudioPlayer
//
// 统一管理天气页的所有音效与氛围音：
//   • 氛围音（ambient）：按天气条件循环播放，状态切换时交叉淡入淡出
//   • 触发音（oneshot）：旋转、日期选择、进入界面等短促音效

final class WeatherAudioPlayer {

    static let shared = WeatherAudioPlayer()

    // MARK: - Internal state

    private var ambientPlayer: AVAudioPlayer?
    private var stingPlayer:   AVAudioPlayer?
    // 预加载的单次播放播放器池（防止重叠时卡顿）
    private var oneshotPool: [String: [AVAudioPlayer]] = [:]

    private init() {
        configureSession()
    }

    // MARK: - Session

    private func configureSession() {
        // .playback + .mixWithOthers：天气氛围音绕过静音键，同时不打断用户正在播放的内容
        try? AVAudioSession.sharedInstance().setCategory(
            .playback,
            options: [.mixWithOthers]
        )
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    // MARK: - Ambient（循环氛围音）

    /// 根据天气条件播放对应氛围音，条件不变时不重新播放
    func playAmbient(for condition: String) {
        let filename = ambientFilename(for: condition)
        // 避免重复切换相同文件
        if let current = ambientPlayer, current.isPlaying,
           current.url?.deletingPathExtension().lastPathComponent == filename { return }

        guard let url = audioURL(filename) else {
            ambientPlayer?.stop()
            ambientPlayer = nil
            return
        }
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.numberOfLoops = -1        // 循环
        player.volume        = 0.0
        player.prepareToPlay()
        player.play()

        // 旧的淡出
        let old = ambientPlayer
        ambientPlayer = player
        fadeVolume(old, to: 0, duration: 1.2) { old?.stop() }
        fadeVolume(player, to: 0.30, duration: 1.2)
    }

    func stopAmbient() {
        fadeVolume(ambientPlayer, to: 0, duration: 0.8) { [weak self] in
            self?.ambientPlayer?.stop()
            self?.ambientPlayer = nil
        }
    }

    // MARK: - Sting（条件切换时的氛围音刺）

    func playSting(for condition: String) {
        let filename = stingFilename(for: condition) ?? ""
        guard !filename.isEmpty, let url = audioURL(filename) else { return }
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.volume = 0.55
        stingPlayer = player
        player.play()
    }

    // MARK: - Oneshot（单次触发音效）

    /// 拖拽开始（轻触反馈）
    func playShapeTap() { playOneshot("shape-tap-1") }

    /// 旋转进行中（根据速度选取快/慢版本）
    func playSpinLoop(fast: Bool) {
        let name = fast ? "spin-fast-4" : "spin-slow-4"
        playOneshot(name, volume: 0.35)
    }

    /// 日期选择器切换
    func playDaySelect() { playOneshot("ui-day-select-1", volume: 0.55) }

    /// 逐小时列表滚动
    func playTimeScroll() { playOneshot("ui-time-scroll-click-1", volume: 0.40) }

    /// 界面进入
    func playDetailedEnter() { playOneshot("menu-open-1", volume: 0.65) }

    // MARK: - Private Helpers

    private func playOneshot(_ name: String, volume: Float = 0.60) {
        // 每个音效最多同时存 2 个播放器，复用已停止的
        var pool = oneshotPool[name] ?? []
        let reusable = pool.first { !$0.isPlaying }
        let player: AVAudioPlayer
        if let r = reusable {
            player = r
            player.currentTime = 0
        } else {
            guard let url = audioURL(name),
                  let p = try? AVAudioPlayer(contentsOf: url) else { return }
            p.prepareToPlay()
            pool.append(p)
            if pool.count > 2 { pool.removeFirst() }
            oneshotPool[name] = pool
            player = p
        }
        player.volume = volume
        player.play()
    }

    private func audioURL(_ name: String) -> URL? {
        guard !name.isEmpty else { return nil }
        // folder reference 下的嵌套文件必须用直接路径拼接，forResource API 对此不可靠
        let direct = Bundle.main.bundleURL
            .appendingPathComponent("WeatherData/Audio/\(name).m4a")
        if FileManager.default.fileExists(atPath: direct.path) { return direct }
        // 降级兜底：标准 API
        return Bundle.main.url(forResource: name, withExtension: "m4a",
                               subdirectory: "WeatherData/Audio")
    }

    // MARK: - Condition → Filename Mapping

    private func ambientFilename(for condition: String) -> String {
        switch condition {
        case "clear", "partlyCloudy":
            return ""                              // 晴天无氛围音
        case "cloudy", "drizzle", "rain", "thunderstorm", "snow", "fog":
            return "weather-ambience-icepellets"  // 唯一可用的氛围音文件
        default:
            return ""
        }
    }

    private func stingFilename(for condition: String) -> String? {
        switch condition {
        case "cloudy", "partlyCloudy":
            return "weather-sting-mostlycloudy"
        case "snow":
            return "weather-sting-snow"
        default:
            return nil
        }
    }

    // MARK: - Volume Fade

    private func fadeVolume(
        _ player: AVAudioPlayer?,
        to target: Float,
        duration: TimeInterval,
        completion: (() -> Void)? = nil
    ) {
        guard let player else { completion?(); return }
        let steps: Int    = 20
        let interval      = duration / Double(steps)
        let delta         = (target - player.volume) / Float(steps)
        var count         = 0
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            count += 1
            player.volume = max(0, min(1, player.volume + delta))
            if count >= steps {
                timer.invalidate()
                player.volume = target
                completion?()
            }
        }
    }
}
