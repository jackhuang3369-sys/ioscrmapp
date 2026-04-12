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
    let condition: WeatherCondition
    let isCurrent: Bool

    /// SF Symbol 名称，从 condition 派生，无需单独存储。
    var sfSymbol: String { condition.sfSymbol }
}

enum MockWeatherData {

    static let today = CurrentWeather(
        city: "Dubai",
        temperature: 31,
        title: "Clear Sky",
        dateText: "TODAY · APR 03"
    )

    static let timeline: [WeatherTimelineEntry] = [
        .init(id: "now", label: "Now", temperature: 31, condition: .clear,  isCurrent: true),
        .init(id: "09", label: "09",  temperature: 32, condition: .clear,  isCurrent: false),
        .init(id: "12", label: "12",  temperature: 33, condition: .clear,  isCurrent: false),
        .init(id: "15", label: "15",  temperature: 35, condition: .clear,  isCurrent: false),
        .init(id: "18", label: "18",  temperature: 34, condition: .clear,  isCurrent: false),
        .init(id: "21", label: "21",  temperature: 25, condition: .sunset, isCurrent: false),
        .init(id: "00", label: "00",  temperature: 23, condition: .night,  isCurrent: false),
        .init(id: "03", label: "03",  temperature: 21, condition: .night,  isCurrent: false),
    ]
}
