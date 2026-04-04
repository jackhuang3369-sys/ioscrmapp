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
        title: "晴朗的天空",
        dateText: "TODAY · APR 03"
    )

    static let timeline: [WeatherTimelineEntry] = [
        .init(id: "now", label: "现在", temperature: 31, symbolName: "sun.max.fill", isCurrent: true),
        .init(id: "09", label: "09", temperature: 32, symbolName: "sun.max.fill", isCurrent: false),
        .init(id: "12", label: "12", temperature: 33, symbolName: "sun.max.fill", isCurrent: false),
        .init(id: "15", label: "15", temperature: 35, symbolName: "sun.max.fill", isCurrent: false),
        .init(id: "18", label: "18", temperature: 34, symbolName: "sun.max.fill", isCurrent: false),
        .init(id: "21", label: "21", temperature: 25, symbolName: "sunset.fill", isCurrent: false),
        .init(id: "00", label: "00", temperature: 23, symbolName: "moon.stars.fill", isCurrent: false),
        .init(id: "03", label: "03", temperature: 21, symbolName: "moon.stars.fill", isCurrent: false)
    ]
}
