import SwiftUI

// MARK: - Bolt Flight Card
/// 航班选项 — 左侧航线视觉 + 右侧价格
struct BoltFlightCard: View {
    let suggestion: TravelSuggestion
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            BoltGlassSurface(cornerRadius: BoltTheme.radiusLg) {
                HStack(spacing: 14) {
                    // 航线视觉
                    FlightRouteIcon()

                    // 航班信息
                    VStack(alignment: .leading, spacing: 5) {
                        Text(suggestion.title)
                            .font(BoltTheme.headingFont(14))
                            .foregroundColor(BoltTheme.textPrimary)
                            .lineLimit(1)

                        Text(suggestion.subtitle)
                            .font(BoltTheme.captionFont(12))
                            .foregroundColor(BoltTheme.textSecondary)
                            .lineLimit(1)

                        if let badge = suggestion.badge {
                            BoltBadge(text: badge, style: .info)
                        }
                    }

                    Spacer()

                    // 价格
                    VStack(alignment: .trailing, spacing: 4) {
                        if let price = suggestion.price {
                            Text(price)
                                .font(BoltTheme.displayFont(17))
                                .foregroundColor(BoltTheme.gold)
                        }
                        if let rating = suggestion.rating {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(BoltTheme.amber)
                                Text(String(format: "%.1f", rating))
                                    .font(BoltTheme.captionFont(11))
                                    .foregroundColor(BoltTheme.textSecondary)
                            }
                        }
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(BoltTheme.textTertiary)
                }
                .padding(14)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Flight Route Icon
private struct FlightRouteIcon: View {
    var body: some View {
        VStack(spacing: 3) {
            Circle()
                .fill(BoltTheme.gold.opacity(0.5))
                .frame(width: 6, height: 6)

            CurvedDashedLine()
                .stroke(BoltTheme.borderMedium, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .frame(width: 1, height: 22)

            Image(systemName: "airplane")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(BoltTheme.gold)
                .rotationEffect(.degrees(90))

            CurvedDashedLine()
                .stroke(BoltTheme.borderMedium, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .frame(width: 1, height: 22)

            Circle()
                .fill(BoltTheme.skyBlue.opacity(0.5))
                .frame(width: 6, height: 6)
        }
    }
}

private struct CurvedDashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return p
    }
}

// MARK: - Bolt Flight List
struct BoltFlightList: View {
    let suggestions: [TravelSuggestion]
    let onSelect: (TravelSuggestion) -> Void

    var body: some View {
        VStack(spacing: BoltTheme.spacingSm) {
            BoltSectionHeader("Available Flights", icon: "airplane")
            ForEach(suggestions.filter { $0.type == .flight }) { suggestion in
                BoltFlightCard(suggestion: suggestion) { onSelect(suggestion) }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 12) {
        BoltFlightCard(suggestion: .init(type: .flight, title: "Emirates EK 302", subtitle: "DXB → SIN · 7h 20m · Direct", price: "$1,240", rating: 4.8, badge: "Best Value", imageURL: nil, actionTitle: "Select"), onTap: {})
        BoltFlightCard(suggestion: .init(type: .flight, title: "Singapore Airlines SQ 495", subtitle: "DXB → SIN · 8h 05m · 1 Stop", price: "$1,380", rating: 4.9, badge: nil, imageURL: nil, actionTitle: "Select"), onTap: {})
    }
    .padding()
    .background(Color(hex: 0x080810))
}
