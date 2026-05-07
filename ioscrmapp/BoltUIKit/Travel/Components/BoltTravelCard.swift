import SwiftUI

// MARK: - Bolt Travel Hero Card
/// 旅行主视觉卡片 v2 — 梦境抽象艺术 + 玻璃态信息层 + 双 CTA
struct BoltHeroTravelCard: View {
    let intent: TravelIntent
    let onExploreFlights: () -> Void
    let onExploreHotels: () -> Void
    @State private var isShowing = false

    var body: some View {
        BoltGlassSurface(cornerRadius: BoltTheme.radiusXl) {
            VStack(spacing: 0) {
                // 梦境画布
                ZStack(alignment: .bottom) {
                    BoltTravelDreamscape(
                        destination: intent.destination,
                        transportMode: intent.transportMode
                    )
                    .frame(height: 180)
                    .clipped()

                    // 底部渐变遮罩
                    LinearGradient(
                        colors: [.clear, Color.black.opacity(0.55), Color.black.opacity(0.85)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 120)

                    // 目的地信息层
                    VStack(alignment: .leading, spacing: 4) {
                        Text(intent.destination)
                            .font(BoltTheme.displayFont(25))
                            .foregroundColor(.white)

                        if let dateRange = intent.formattedDateRange {
                            HStack(spacing: BoltTheme.spacingXs) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 11, weight: .medium))
                                Text(dateRange)
                                    .font(BoltTheme.bodyFont(12))
                            }
                            .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, BoltTheme.spacingLg)
                    .padding(.bottom, BoltTheme.spacingMd)
                }

                // 信息层
                VStack(spacing: BoltTheme.spacingMd) {
                    // 旅行摘要行
                    HStack(spacing: 0) {
                        SummaryPill(icon: intent.transportMode.icon, text: intent.transportMode.displayName)
                        if let nights = intent.nightsCount {
                            SummaryPill(icon: "moon.stars.fill", text: "\(nights) nights")
                        }
                        if intent.passengerCount > 0 {
                            SummaryPill(icon: "person.2.fill", text: "\(intent.passengerCount)")
                        }
                        Spacer()
                    }

                    // 价格
                    if let priceRange = intent.priceRange {
                        Divider().background(BoltTheme.borderSubtle)

                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("from")
                                .font(BoltTheme.bodyFont(11))
                                .foregroundColor(BoltTheme.textTertiary)
                            Text(priceRange.displayText)
                                .font(BoltTheme.displayFont(23))
                                .foregroundColor(BoltTheme.gold)

                            Spacer()

                            BoltBadge(text: "per person", style: .gold)
                        }
                    }

                    // CTA
                    if let _ = intent.priceRange {
                        Divider().background(BoltTheme.borderSubtle)

                        HStack(spacing: 10) {
                            BoltGlowButton(
                                "Explore Flights",
                                icon: "airplane",
                                gradient: [BoltTheme.gold, BoltTheme.sunset],
                                action: onExploreFlights
                            )

                            BoltGhostButton(
                                "Hotels",
                                icon: "bed.double.fill",
                                action: onExploreHotels
                            )
                            .frame(width: 110)
                        }
                    }
                }
                .padding(BoltTheme.spacingLg)
            }
        }
        .opacity(isShowing ? 1 : 0)
        .offset(y: isShowing ? 0 : 30)
        .onAppear {
            withAnimation(BoltTheme.springEase) { isShowing = true }
        }
    }
}

// MARK: - Summary Pill
private struct SummaryPill: View {
    let icon: String; let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(BoltTheme.gold.opacity(0.7))
            Text(text)
                .font(BoltTheme.bodyFont(11))
                .foregroundColor(BoltTheme.textSecondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Capsule().fill(BoltTheme.surfaceRaised)
            .overlay(Capsule().stroke(BoltTheme.borderSubtle, lineWidth: 0.5)))
        .padding(.trailing, 6)
    }
}

// MARK: - Bolt Travel Card (compat alias)
typealias BoltTravelCard = BoltHeroTravelCard

// MARK: - Preview
#Preview {
    ScrollView {
        VStack(spacing: 24) {
            BoltHeroTravelCard(
                intent: TravelIntent(
                    destination: "Dubai, UAE",
                    departureDate: Date(),
                    returnDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()),
                    transportMode: .flight,
                    passengerCount: 2,
                    priceRange: TravelIntent.PriceRange(min: 299, max: 599, currency: "USD"),
                    suggestions: []
                ),
                onExploreFlights: {},
                onExploreHotels: {}
            )
            .padding(.horizontal)

            BoltHeroTravelCard(
                intent: TravelIntent(
                    destination: "Tokyo, Japan",
                    departureDate: Date(),
                    returnDate: nil,
                    transportMode: .train,
                    passengerCount: 1,
                    priceRange: nil,
                    suggestions: []
                ),
                onExploreFlights: {},
                onExploreHotels: {}
            )
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
    .background(Color(hex: 0x080810))
}
