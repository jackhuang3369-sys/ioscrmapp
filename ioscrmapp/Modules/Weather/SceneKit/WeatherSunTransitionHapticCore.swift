import Foundation

enum WeatherSunTransitionHapticCore {
    static let totalDuration: TimeInterval = 0.38
    static let startIntensity: Float = 0.8
    static let endIntensity: Float = 0.1
    static let sharpness: Float = 0.5

    /// 返回震动在时刻 t（秒）的线性插值 intensity。
    /// t 被 clamp 到 [0, totalDuration]，结果 clamp 到 [endIntensity, startIntensity]。
    static func intensity(at t: TimeInterval) -> Float {
        let progress = Float(min(max(t / totalDuration, 0), 1))
        let value = startIntensity + (endIntensity - startIntensity) * progress
        return min(max(value, endIntensity), startIntensity)
    }
}
