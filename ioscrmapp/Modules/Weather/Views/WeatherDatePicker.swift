import SwiftUI

// MARK: - WeatherDatePicker（日期切换条）

struct WeatherDatePicker: View {
    let days: [DayForecast]
    @Binding var selectedIndex: Int

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(days.indices, id: \.self) { i in
                    let day = days[i]
                    let isSelected = i == selectedIndex

                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedIndex = i
                        }
                    } label: {
                        VStack(spacing: 2) {
                            Text(day.weekday)
                                .font(.du(13, weight: isSelected ? .semibold : .regular))
                                .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                            Text(day.date)
                                .font(.du(11, weight: .regular))
                                .foregroundColor(isSelected ? .white.opacity(0.8) : .white.opacity(0.4))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white.opacity(0.2) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }
}
