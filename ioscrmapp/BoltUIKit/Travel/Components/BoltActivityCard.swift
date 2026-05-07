import SwiftUI

// MARK: - Bolt Activity Card
/// 体验卡片 v2 — 左侧金色彩条 + 渐变背景
struct BoltActivityCard: View {
    let suggestion: TravelSuggestion
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            BoltGlassSurface(cornerRadius: BoltTheme.radiusLg) {
                HStack(spacing: 0) {
                    // 金色彩条
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(LinearGradient(
                            colors: [BoltTheme.gold, BoltTheme.amber, BoltTheme.sunset],
                            startPoint: .top, endPoint: .bottom))
                        .frame(width: 3)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            HStack(spacing: 5) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(BoltTheme.gold)
                                Text(suggestion.type.displayName.uppercased())
                                    .font(BoltTheme.captionFont(10).bold())
                                    .foregroundColor(BoltTheme.gold)
                                    .tracking(1)
                            }
                            Spacer()
                            if let badge = suggestion.badge {
                                BoltBadge(text: badge, style: .info)
                            }
                        }

                        Text(suggestion.title)
                            .font(BoltTheme.headingFont(14))
                            .foregroundColor(BoltTheme.textPrimary)
                            .lineLimit(2)

                        Text(suggestion.subtitle)
                            .font(BoltTheme.captionFont(12))
                            .foregroundColor(BoltTheme.textSecondary)
                            .lineLimit(2)

                        HStack {
                            if let rating = suggestion.rating {
                                HStack(spacing: 3) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(BoltTheme.amber)
                                    Text(String(format: "%.1f", rating))
                                        .font(BoltTheme.headingFont(12))
                                        .foregroundColor(BoltTheme.textPrimary)
                                }
                            }
                            Spacer()
                            if let price = suggestion.price {
                                Text(price)
                                    .font(BoltTheme.displayFont(16))
                                    .foregroundColor(BoltTheme.gold)
                            }
                        }

                        // CTA 微标签
                        Text(suggestion.actionTitle)
                            .font(BoltTheme.captionFont(11).bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(
                                Capsule().fill(LinearGradient(
                                    colors: [BoltTheme.gold, BoltTheme.amber],
                                    startPoint: .leading, endPoint: .trailing))
                            )
                    }
                    .padding(14)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(BoltTheme.textTertiary)
                        .padding(.trailing, 12)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Bolt Activity List
struct BoltActivityList: View {
    let suggestions: [TravelSuggestion]
    let onSelect: (TravelSuggestion) -> Void

    var body: some View {
        VStack(spacing: BoltTheme.spacingSm) {
            BoltSectionHeader("Experiences", icon: "sparkles")
            ForEach(suggestions.filter { $0.type == .activity }) { suggestion in
                BoltActivityCard(suggestion: suggestion) { onSelect(suggestion) }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 12) {
        BoltActivityCard(suggestion: .init(type: .activity, title: "Desert Safari & BBQ", subtitle: "Evening dunes drive with dinner and live entertainment", price: "$89/person", rating: 4.6, badge: "Bestseller", imageURL: nil, actionTitle: "Book Now"), onTap: {})
        BoltActivityCard(suggestion: .init(type: .activity, title: "Dhow Dinner Cruise", subtitle: "Traditional sailing with buffet and skyline views", price: "$120/person", rating: 4.8, badge: nil, imageURL: nil, actionTitle: "View Details"), onTap: {})
    }
    .padding()
    .background(Color(hex: 0x080810))
}
