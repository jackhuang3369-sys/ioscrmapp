import Foundation

// MARK: - Detail Dimension

enum WeatherDetailDimension: Int, CaseIterable, Identifiable {
    case temperature
    case wind
    case precipitation
    case air

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .temperature:  return "Temperature"
        case .wind:         return "Wind"
        case .precipitation: return "Precipitation"
        case .air:          return "Air Quality"
        }
    }

    var sfSymbol: String {
        switch self {
        case .temperature:   return "thermometer.medium"
        case .wind:          return "wind"
        case .precipitation: return "drop.fill"
        case .air:           return "aqi.medium"
        }
    }
}
