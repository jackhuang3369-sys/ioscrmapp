import SwiftUI

// MARK: - Bolt Package Card
/// 套餐卡 v2 — 顶部渐变彩带 + 内容 + 渐变CTA
struct BoltPackageCard: View {
    let suggestion: TravelSuggestion
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            BoltElevatedCard(glowColor: BoltTheme.gold.opacity(0.25), padding: 0) {
                VStack(spacing: 0) {
                    // 顶部彩带
                    ZStack {
                        LinearGradient(
                            colors: [BoltTheme.gold.opacity(0.4), BoltTheme.lavender.opacity(0.3), BoltTheme.skyBlue.opacity(0.25)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                        .frame(height: 60)

                        // 环形装饰
                        GeometryReader { geo in
                            Circle()
                                .stroke(BoltTheme.gold.opacity(0.15), lineWidth: 1)
                                .frame(width: 80, height: 80)
                                .offset(x: geo.size.width * 0.6, y: -geo.size.height * 0.5)

                            Circle()
                                .fill(BoltTheme.lavender.opacity(0.1))
                                .frame(width: 50, height: 50)
                                .offset(x: -geo.size.width * 0.1, y: -geo.size.height * 0.7)
                        }

                        HStack {
                            Image(systemName: "square.stack.3d.up.fill")
                                .font(.system(size: 16, weight: .light))
                                .foregroundColor(.white.opacity(0.6))
                            Text("Package Deal")
                                .font(BoltTheme.captionFont(11).bold())
                                .foregroundColor(.white.opacity(0.6))
                                .tracking(1.5)
                            Spacer()
                            if let badge = suggestion.badge {
                                BoltBadge(text: badge, style: .gold)
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    // 内容
                    VStack(alignment: .leading, spacing: BoltTheme.spacingMd) {
                        Text(suggestion.title)
                            .font(BoltTheme.headingFont(16))
                            .foregroundColor(BoltTheme.textPrimary)

                        Text(suggestion.subtitle)
                            .font(BoltTheme.bodyFont(13))
                            .foregroundColor(BoltTheme.textSecondary)
                            .lineLimit(2)

                        // 包含项
                        HStack(spacing: 8) {
                            PackageChip(icon: "airplane", text: "Flight")
                            PackageChip(icon: "bed.double.fill", text: "Hotel")
                            PackageChip(icon: "car.fill", text: "Transfer")
                        }

                        Divider().background(BoltTheme.borderSubtle)

                        // 价格 + CTA
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Total").font(BoltTheme.captionFont(11)).foregroundColor(BoltTheme.textTertiary)
                                if let price = suggestion.price {
                                    Text(price)
                                        .font(BoltTheme.displayFont(24))
                                        .foregroundColor(BoltTheme.gold)
                                }
                            }
                            Spacer()
                            Text(suggestion.actionTitle)
                                .font(BoltTheme.headingFont(13))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20).padding(.vertical, 12)
                                .background(
                                    Capsule().fill(LinearGradient(
                                        colors: [BoltTheme.gold, BoltTheme.sunset],
                                        startPoint: .leading, endPoint: .trailing))
                                )
                        }
                    }
                    .padding(16)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Package Chip
struct PackageChip: View {
    let icon: String; let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
            Text(text)
                .font(BoltTheme.captionFont(10).bold())
        }
        .foregroundColor(BoltTheme.textSecondary)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Capsule().fill(BoltTheme.surfaceRaised)
            .overlay(Capsule().stroke(BoltTheme.borderSubtle, lineWidth: 0.5)))
    }
}

// MARK: - Bolt Package List
struct BoltPackageList: View {
    let suggestions: [TravelSuggestion]
    let onSelect: (TravelSuggestion) -> Void

    var body: some View {
        VStack(spacing: BoltTheme.spacingMd) {
            BoltSectionHeader("Travel Packages", icon: "square.stack.3d.up.fill")
            ForEach(suggestions.filter { $0.type == .package }) { suggestion in
                BoltPackageCard(suggestion: suggestion) { onSelect(suggestion) }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ScrollView {
        BoltPackageCard(suggestion: .init(type: .package, title: "Dubai Golden Escape", subtitle: "5 nights at Palm Jumeirah + round-trip flights + private airport transfer", price: "$1,299", rating: 4.8, badge: "Best Seller", imageURL: nil, actionTitle: "View Details"), onTap: {})
            .padding()
    }
    .background(Color(hex: 0x080810))
}
