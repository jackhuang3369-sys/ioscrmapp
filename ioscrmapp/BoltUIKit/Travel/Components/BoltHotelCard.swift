import SwiftUI

// MARK: - Bolt Hotel Card
/// 酒店卡片 v2 — 顶部梦境画布 + 底部信息
struct BoltHotelCard: View {
    let suggestion: TravelSuggestion
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            BoltGlassSurface(cornerRadius: BoltTheme.radiusLg) {
                VStack(spacing: 0) {
                    // 顶部：微型梦境画布
                    GeometryReader { geo in
                        ZStack(alignment: .bottomLeading) {
                            // 深色调渐变
                            LinearGradient(
                                colors: [Color(hex: 0x1B3240), Color(hex: 0x2D1B40), Color(hex: 0x1A2A38)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )

                            // 环形光晕
                            Circle()
                                .fill(RadialGradient(
                                    colors: [BoltTheme.gold.opacity(0.18), .clear],
                                    center: .center, startRadius: 0,
                                    endRadius: geo.size.width * 0.8))
                                .frame(width: geo.size.width * 1.4, height: geo.size.width * 1.4)
                                .offset(x: geo.size.width * 0.2, y: -geo.size.height * 0.5)

                            // 网格
                            HotelGrid(density: 8, opacity: 0.04, color: .white)

                            // Badge
                            if let badge = suggestion.badge {
                                VStack {
                                    HStack {
                                        Spacer()
                                        BoltBadge(text: badge, style: .premium)
                                            .padding(10)
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                    .frame(height: 90)
                    .clipped()

                    // 信息区域
                    VStack(alignment: .leading, spacing: 8) {
                        Text(suggestion.title)
                            .font(BoltTheme.headingFont(14))
                            .foregroundColor(BoltTheme.textPrimary)
                            .lineLimit(1)

                        Text(suggestion.subtitle)
                            .font(BoltTheme.captionFont(12))
                            .foregroundColor(BoltTheme.textSecondary)
                            .lineLimit(1)

                        HStack {
                            if let rating = suggestion.rating {
                                HStack(spacing: 3) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(BoltTheme.amber)
                                    Text(String(format: "%.1f", rating))
                                        .font(BoltTheme.headingFont(12))
                                        .foregroundColor(BoltTheme.textPrimary)
                                }
                            }
                            Spacer()
                            if let price = suggestion.price {
                                Text(price)
                                    .font(BoltTheme.displayFont(17))
                                    .foregroundColor(BoltTheme.gold)
                            }
                        }
                    }
                    .padding(12)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct HotelGrid: View {
    let density: Int; let opacity: Double; let color: Color
    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, _ in
                let stepX = geo.size.width / CGFloat(density)
                let stepY = geo.size.height / CGFloat(density)
                for i in 0...density {
                    ctx.stroke(Path { p in
                        p.move(to: CGPoint(x: 0, y: stepY * CGFloat(i)))
                        p.addLine(to: CGPoint(x: geo.size.width, y: stepY * CGFloat(i)))
                    }, with: .color(color.opacity(opacity)), lineWidth: 0.5)
                    ctx.stroke(Path { p in
                        p.move(to: CGPoint(x: stepX * CGFloat(i), y: 0))
                        p.addLine(to: CGPoint(x: stepX * CGFloat(i), y: geo.size.height))
                    }, with: .color(color.opacity(opacity)), lineWidth: 0.5)
                }
            }
        }
    }
}

// MARK: - Bolt Hotel Grid
struct BoltHotelGrid: View {
    let suggestions: [TravelSuggestion]
    let onSelect: (TravelSuggestion) -> Void
    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: BoltTheme.spacingMd) {
            BoltSectionHeader("Recommended Hotels", icon: "bed.double.fill")
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(suggestions.filter { $0.type == .hotel }) { suggestion in
                    BoltHotelCard(suggestion: suggestion) { onSelect(suggestion) }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    HStack(spacing: 10) {
        BoltHotelCard(suggestion: .init(type: .hotel, title: "Marina Bay", subtitle: "Marina District, Dubai", price: "$280/night", rating: 4.7, badge: "Popular", imageURL: nil, actionTitle: "View"), onTap: {})
        BoltHotelCard(suggestion: .init(type: .hotel, title: "Palm View", subtitle: "Palm Jumeirah, Dubai", price: "$420/night", rating: 4.9, badge: "Premium", imageURL: nil, actionTitle: "View"), onTap: {})
    }
    .padding()
    .background(Color(hex: 0x080810))
}
