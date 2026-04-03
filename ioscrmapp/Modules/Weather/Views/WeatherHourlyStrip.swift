import SwiftUI

// MARK: - WeatherHourlyStrip（逐小时预报横向条）

struct WeatherHourlyStrip: View {
    let hourly: [HourlyForecast]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(hourly) { item in
                    HourlyCell(item: item)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .clipped()
    }
}

// MARK: - HourlyCell

private struct HourlyCell: View {
    let item: HourlyForecast

    var body: some View {
        VStack(spacing: 6) {
            Text(item.hour)
                .font(.du(12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))

            Image(systemName: item.condition.sfSymbol)
                .font(.system(size: 20))
                .foregroundStyle(.white)

            Text("\(item.temperature)°")
                .font(.du(14, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(width: 56)
        .padding(.vertical, 4)
    }
}
