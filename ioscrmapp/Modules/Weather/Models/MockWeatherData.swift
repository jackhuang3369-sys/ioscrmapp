import Foundation

// MARK: - Data Structures

struct CurrentWeather {
    let city: String
    let temperature: Int        // °F
    let feelsLike: Int
    let high: Int
    let low: Int
    let condition: WeatherCondition
    var isNight: Bool
}

struct HourlyForecast: Identifiable {
    let id = UUID()
    let hour: String            // "Now" / "7 AM" etc.
    let condition: WeatherCondition
    let temperature: Int
}

struct DayForecast: Identifiable {
    let id = UUID()
    let weekday: String         // "Today" / "Tue" etc.
    let date: String            // "Apr 2"
    let condition: WeatherCondition
    let high: Int
    let low: Int
}

// MARK: - Detail Dimension Data

struct WeatherTempDetail {
    let current: Int
    let feelsLike: Int
    let high: Int
    let low: Int
    /// 24h 温度曲线（小时偏移 → 温度）
    let curve: [(hour: Int, temp: Int)]
}

struct WeatherWindDetail {
    let speed: Int              // mph
    let direction: String       // "WSW"
    let directionDegrees: Double // 0-360
    let gust: Int
}

struct WeatherPrecipDetail {
    let probability: Int        // %
    let accumulation: Double    // inches
    /// 分钟级时间轴 (分钟偏移, 降水强度 0-100)
    let minutely: [(minute: Int, intensity: Int)]
}

struct WeatherAirDetail {
    let aqi: Int
    let level: String           // "Good" / "Moderate" etc.
    let uv: Int
    let uvLevel: String         // "Low" / "Moderate" etc.
    let visibility: Int         // miles
    let humidity: Int           // %
}

struct WeatherDetailData {
    let temperature: WeatherTempDetail
    let wind: WeatherWindDetail
    let precipitation: WeatherPrecipDetail
    let air: WeatherAirDetail
}

// MARK: - Mock Data

enum MockWeatherData {

    static let current = CurrentWeather(
        city: "San Francisco",
        temperature: 72,
        feelsLike: 68,
        high: 79,
        low: 61,
        condition: .partlyCloudy,
        isNight: false
    )

    static let hourly: [HourlyForecast] = [
        .init(hour: "Now",   condition: .partlyCloudy, temperature: 72),
        .init(hour: "7 AM",  condition: .clear,        temperature: 68),
        .init(hour: "8 AM",  condition: .clear,        temperature: 70),
        .init(hour: "9 AM",  condition: .partlyCloudy, temperature: 73),
        .init(hour: "10 AM", condition: .partlyCloudy, temperature: 75),
        .init(hour: "11 AM", condition: .cloudy,       temperature: 74),
        .init(hour: "12 PM", condition: .rain,         temperature: 71),
        .init(hour: "1 PM",  condition: .rain,         temperature: 69),
        .init(hour: "2 PM",  condition: .thunderstorm, temperature: 66),
        .init(hour: "3 PM",  condition: .thunderstorm, temperature: 64),
        .init(hour: "4 PM",  condition: .cloudy,       temperature: 65),
        .init(hour: "5 PM",  condition: .partlyCloudy, temperature: 67),
    ]

    static let daily: [DayForecast] = [
        .init(weekday: "Today", date: "Apr 2",  condition: .partlyCloudy, high: 79, low: 61),
        .init(weekday: "Tue",   date: "Apr 3",  condition: .clear,        high: 82, low: 63),
        .init(weekday: "Wed",   date: "Apr 4",  condition: .rain,         high: 70, low: 58),
        .init(weekday: "Thu",   date: "Apr 5",  condition: .snow,         high: 65, low: 52),
        .init(weekday: "Fri",   date: "Apr 6",  condition: .thunderstorm, high: 68, low: 55),
        .init(weekday: "Sat",   date: "Apr 7",  condition: .fog,          high: 66, low: 57),
        .init(weekday: "Sun",   date: "Apr 8",  condition: .clear,        high: 75, low: 60),
    ]

    static let detail = WeatherDetailData(
        temperature: WeatherTempDetail(
            current: 72, feelsLike: 68, high: 79, low: 61,
            curve: [
                (0, 63), (3, 61), (6, 62), (9, 68),
                (12, 74), (15, 77), (18, 75), (21, 69), (24, 64)
            ]
        ),
        wind: WeatherWindDetail(
            speed: 12, direction: "WSW", directionDegrees: 247.5, gust: 18
        ),
        precipitation: WeatherPrecipDetail(
            probability: 20, accumulation: 0.04,
            minutely: [
                (0,0),(5,0),(10,2),(15,8),(20,15),(25,22),
                (30,18),(35,10),(40,5),(45,2),(50,0),(55,0)
            ]
        ),
        air: WeatherAirDetail(
            aqi: 42, level: "Good",
            uv: 4, uvLevel: "Moderate",
            visibility: 10, humidity: 74
        )
    )
}
