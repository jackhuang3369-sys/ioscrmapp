import CoreHaptics

final class WeatherHapticPlayer {

    static let shared = WeatherHapticPlayer()

    private var engine: CHHapticEngine?
    private var currentPlayer: CHHapticPatternPlayer?

    private init() {}

    func prepareSunTransition() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        if engine == nil {
            engine = try? CHHapticEngine()
            engine?.isAutoShutdownEnabled = true
        }
        engine?.start(completionHandler: { _ in })
    }

    func playSunTransitionFade() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine else { return }

        try? currentPlayer?.stop(atTime: CHHapticTimeImmediate)
        currentPlayer = nil

        let duration = WeatherSunTransitionHapticCore.totalDuration
        let startI = WeatherSunTransitionHapticCore.startIntensity
        let endI = WeatherSunTransitionHapticCore.endIntensity
        let sharp = WeatherSunTransitionHapticCore.sharpness

        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: startI),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharp)
            ],
            relativeTime: 0,
            duration: duration
        )

        let intensityCurve = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                CHHapticParameterCurve.ControlPoint(relativeTime: 0, value: startI),
                CHHapticParameterCurve.ControlPoint(relativeTime: duration, value: endI)
            ],
            relativeTime: 0
        )

        guard let pattern = try? CHHapticPattern(events: [event], parameterCurves: [intensityCurve]) else { return }
        currentPlayer = try? engine.makePlayer(with: pattern)
        try? currentPlayer?.start(atTime: CHHapticTimeImmediate)
    }
}
