import Foundation

struct CurrentWeather {
    let city: String
    let temperature: Int
    let title: String
    let dateText: String
}

struct WeatherTimelineEntry: Identifiable {
    let id: String
    let label: String
    let temperature: Int
    let symbolName: String
    let isCurrent: Bool
}

enum MockWeatherData {

    static let today = CurrentWeather(
        city: "Dubai",
        temperature: 31,
        title: "Clear Sky",
        dateText: "TODAY · APR 03"
    )

    static let timeline: [WeatherTimelineEntry] = [
        .init(id: "now", label: "Now", temperature: 31, symbolName: "sun.max.fill", isCurrent: true),
        .init(id: "09", label: "09", temperature: 32, symbolName: "sun.max.fill", isCurrent: false),
        .init(id: "12", label: "12", temperature: 33, symbolName: "sun.max.fill", isCurrent: false),
        .init(id: "15", label: "15", temperature: 35, symbolName: "sun.max.fill", isCurrent: false),
        .init(id: "18", label: "18", temperature: 34, symbolName: "sun.max.fill", isCurrent: false),
        .init(id: "21", label: "21", temperature: 25, symbolName: "sunset.fill", isCurrent: false),
        .init(id: "00", label: "00", temperature: 23, symbolName: "moon.stars.fill", isCurrent: false),
        .init(id: "03", label: "03", temperature: 21, symbolName: "moon.stars.fill", isCurrent: false)
    ]

    static let hourlyDemoPoints: [WeatherHourlyStripPoint] = [
        hourlyPoint(id: "now", hour: 8, label: "NOW", temperature: 31, scenePreset: .sunny, isCurrent: true),
        hourlyPoint(hour: 9, temperature: 32, scenePreset: .sunCloudy),
        hourlyPoint(hour: 10, temperature: 33, scenePreset: .sunCloudy2),
        hourlyPoint(hour: 11, temperature: 34, scenePreset: .sunny),
        hourlyPoint(hour: 12, temperature: 35, scenePreset: .sunCloudy2),
        hourlyPoint(hour: 13, temperature: 36, scenePreset: .sunny),
        hourlyPoint(hour: 14, temperature: 34, scenePreset: .sunCloudy),
        hourlyPoint(hour: 15, temperature: 33, scenePreset: .cloud),
        hourlyPoint(hour: 16, temperature: 32, scenePreset: .sunCloudy2),
        hourlyPoint(hour: 17, temperature: 31, scenePreset: .sunCloudy),
        hourlyPoint(hour: 18, temperature: 30, scenePreset: .moonCloudy2),
        hourlyPoint(hour: 19, temperature: 29, scenePreset: .moonCloudy),
        hourlyPoint(hour: 20, temperature: 28, scenePreset: .moon),
        hourlyPoint(hour: 21, temperature: 27, scenePreset: .moonCloudy),
        hourlyPoint(hour: 22, temperature: 26, scenePreset: .moonCloudy2),
        hourlyPoint(hour: 23, temperature: 25, scenePreset: .moon),
        hourlyPoint(hour: 0, temperature: 24, scenePreset: .moon),
        hourlyPoint(hour: 1, temperature: 23, scenePreset: .moonCloudy),
        hourlyPoint(hour: 2, temperature: 22, scenePreset: .cloud),
        hourlyPoint(hour: 3, temperature: 21, scenePreset: .moonCloudy2),
        hourlyPoint(hour: 4, temperature: 22, scenePreset: .moon),
        hourlyPoint(hour: 5, temperature: 23, scenePreset: .moonCloudy),
        hourlyPoint(hour: 6, temperature: 25, scenePreset: .sunCloudy),
        hourlyPoint(hour: 7, temperature: 28, scenePreset: .sunny)
    ]

    private static func hourlyPoint(
        id: String? = nil,
        hour: Int,
        label: String? = nil,
        temperature: Int,
        scenePreset: WeatherHomeScenePreset,
        isCurrent: Bool = false
    ) -> WeatherHourlyStripPoint {
        WeatherHourlyStripPoint(
            id: id ?? String(format: "%02d", hour),
            hour24: hour,
            label: label ?? String(format: "%02d", hour),
            temperature: temperature,
            isCurrent: isCurrent,
            scenePreset: scenePreset
        )
    }
}
