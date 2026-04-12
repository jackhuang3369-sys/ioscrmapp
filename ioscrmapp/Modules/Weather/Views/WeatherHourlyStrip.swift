import SwiftUI

struct WeatherHourlyStrip: View {
    let timeline: [WeatherTimelineEntry]
    let selectedID: String
    let onSelect: (WeatherTimelineEntry) -> Void

    var body: some View {
        GeometryReader { proxy in
            let sidePadding: CGFloat = 8
            let contentWidth = proxy.size.width - sidePadding * 2
            let itemWidth = contentWidth / CGFloat(max(timeline.count, 1))
            let selectedIndex = CGFloat(timeline.firstIndex(where: { $0.id == selectedID }) ?? 0)
            let selectedCenterX = sidePadding + itemWidth * selectedIndex + itemWidth / 2
            let selectorWidth: CGFloat = 10
            let trackHeight: CGFloat = 42
            let selectorHeight: CGFloat = 30

            VStack(spacing: 8) {
                HStack(spacing: 0) {
                    ForEach(timeline) { item in
                        topValue(for: item)
                            .frame(width: itemWidth)
                    }
                }

                HStack(spacing: 0) {
                    ForEach(timeline) { item in
                        timelineIcon(for: item)
                            .frame(width: itemWidth)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onSelect(item)
                            }
                    }
                }

                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.black.opacity(0.05))
                        .frame(width: contentWidth, height: trackHeight)

                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.black.opacity(0.28))
                        .frame(width: selectorWidth, height: selectorHeight)
                        .position(x: selectedCenterX, y: trackHeight / 2)
                        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: selectedID)
                }
                .frame(height: trackHeight)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let localX = min(max(value.location.x - sidePadding, 0), contentWidth)
                            let rawIndex = Int(localX / max(itemWidth, 1))
                            let clampedIndex = min(max(rawIndex, 0), max(timeline.count - 1, 0))
                            guard timeline.indices.contains(clampedIndex) else { return }
                            let item = timeline[clampedIndex]
                            if item.id != selectedID {
                                onSelect(item)
                            }
                        }
                )

                HStack(spacing: 0) {
                    ForEach(timeline) { item in
                        Text(item.label)
                            .font(.du(11, weight: .medium))
                            .foregroundColor(Color.black.opacity(item.id == selectedID ? 0.6 : 0.34))
                            .frame(width: itemWidth)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onSelect(item)
                            }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 108)
    }

    private func topValue(for item: WeatherTimelineEntry) -> some View {
        Text("\(item.temperature)")
            .font(.du(14, weight: item.id == selectedID ? .bold : .semibold))
            .foregroundColor(Color.black.opacity(item.id == selectedID ? 0.95 : 0.68))
            .frame(height: 22)
    }

    private func timelineIcon(for item: WeatherTimelineEntry) -> some View {
        Image(systemName: item.sfSymbol)
            .font(.system(size: 13, weight: item.id == selectedID ? .semibold : .regular))
            .symbolRenderingMode(.palette)
            .foregroundStyle(iconPrimaryColor(for: item), iconSecondaryColor(for: item))
            .opacity(item.id == selectedID ? 1 : 0.88)
            .frame(height: 16)
    }

    private func iconPrimaryColor(for item: WeatherTimelineEntry) -> Color {
        switch item.condition {
        case .night:  return Color(hex: 0xF4C95D)
        case .sunset: return Color(hex: 0xF28C52)
        default:      return Color(hex: 0xF6B73C)
        }
    }

    private func iconSecondaryColor(for item: WeatherTimelineEntry) -> Color {
        switch item.condition {
        case .night:  return Color(hex: 0xB8B5C0)
        case .sunset: return Color(hex: 0xF8CF8A)
        default:      return Color(hex: 0xFDE7A1)
        }
    }
}
