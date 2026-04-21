import Dispatch

final class WeatherEntryPreloader {

    static let shared = WeatherEntryPreloader()

    private let preloadQueue = DispatchQueue(
        label: "com.ioscrmapp.weather.entry-preload",
        qos: .userInitiated
    )
    private let stateQueue = DispatchQueue(label: "com.ioscrmapp.weather.entry-preload.state")
    private var preparedTransitionManager: WeatherSceneManager?
    private var isPreparingTransitionManager = false

    private init() {}

    func prepareIfNeeded(
        temperature: Int = MockWeatherData.today.temperature,
        temperatures: [Int] = MockWeatherData.hourlyDemoPoints.map(\.temperature)
    ) {
        prewarmRuntimeFeedback()

        let shouldStartPreparing = stateQueue.sync { () -> Bool in
            guard preparedTransitionManager == nil, !isPreparingTransitionManager else {
                return false
            }
            isPreparingTransitionManager = true
            return true
        }

        guard shouldStartPreparing else { return }

        preloadQueue.async { [weak self] in
            guard let self else { return }
            let manager = WeatherSceneManager(
                temperature: temperature,
                mode: .sunTransition
            )
            manager.prewarmTemperatureNodes(for: temperatures)

            self.stateQueue.async {
                self.preparedTransitionManager = manager
                self.isPreparingTransitionManager = false
            }
        }
    }

    func makeTransitionManager(
        temperature: Int,
        temperatures: [Int],
        completion: @escaping (WeatherSceneManager) -> Void
    ) {
        prewarmRuntimeFeedback()

        if let preparedManager = takePreparedTransitionManager() {
            preparedManager.setTemperature(temperature, animated: false)
            preparedManager.prewarmTemperatureNodes(for: temperatures)
            DispatchQueue.main.async {
                completion(preparedManager)
            }
            prepareIfNeeded(temperature: temperature, temperatures: temperatures)
            return
        }

        preloadQueue.async {
            let manager = WeatherSceneManager(
                temperature: temperature,
                mode: .sunTransition
            )
            manager.prewarmTemperatureNodes(for: temperatures)
            DispatchQueue.main.async {
                completion(manager)
            }
        }
    }

    private func takePreparedTransitionManager() -> WeatherSceneManager? {
        stateQueue.sync {
            let manager = preparedTransitionManager
            preparedTransitionManager = nil
            return manager
        }
    }

    private func prewarmRuntimeFeedback() {
        WeatherAudioPlayer.shared.prewarm(
            [
                "menu-open-1",
                "sun-detail-enter",
                "sun-detail-exit",
                "ui-time-scroll-click-1",
                "ui-day-select-1"
            ],
            maxConcurrentPlayers: 1
        )
        DispatchQueue.main.async {
            WeatherHapticPlayer.shared.prepareSunTransition()
        }
    }
}
