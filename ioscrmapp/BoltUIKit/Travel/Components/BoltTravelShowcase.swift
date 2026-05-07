import SwiftUI

// MARK: - Bolt Travel Showcase
/// 旅行完整展示容器 - 整合所有旅行组件
struct BoltTravelShowcase: View {
    let intent: TravelIntent
    let onExploreFlights: () -> Void
    let onExploreHotels: () -> Void
    let onSelectSuggestion: (TravelSuggestion) -> Void

    var body: some View {
        VStack(spacing: BoltTheme.spacingLg) {
            // Hero section
            BoltTravelCard(
                intent: intent,
                onExploreFlights: onExploreFlights,
                onExploreHotels: onExploreHotels
            )

            // Suggestions section
            if !intent.suggestions.isEmpty {
                // Flights
                let flightSuggestions = intent.suggestions.filter { $0.type == .flight }
                if !flightSuggestions.isEmpty {
                    BoltFlightList(suggestions: flightSuggestions) { suggestion in
                        onSelectSuggestion(suggestion)
                    }
                }

                // Hotels
                let hotelSuggestions = intent.suggestions.filter { $0.type == .hotel }
                if !hotelSuggestions.isEmpty {
                    BoltHotelGrid(suggestions: hotelSuggestions) { suggestion in
                        onSelectSuggestion(suggestion)
                    }
                }

                // Activities
                let activitySuggestions = intent.suggestions.filter { $0.type == .activity }
                if !activitySuggestions.isEmpty {
                    BoltActivityList(suggestions: activitySuggestions) { suggestion in
                        onSelectSuggestion(suggestion)
                    }
                }

                // Packages
                let packageSuggestions = intent.suggestions.filter { $0.type == .package }
                if !packageSuggestions.isEmpty {
                    BoltPackageList(suggestions: packageSuggestions) { suggestion in
                        onSelectSuggestion(suggestion)
                    }
                }
            }
        }
    }
}

// MARK: - Bolt Travel Empty State
/// 无搜索结果时的空状态
struct BoltTravelEmptyState: View {
    let destination: String
    let onSearch: () -> Void

    var body: some View {
        BoltGlassSurface(padding: BoltTheme.spacingXl, cornerRadius: BoltTheme.radiusLg) {
            VStack(spacing: BoltTheme.spacingMd) {
                // Icon
                ZStack {
                    Circle()
                        .fill(BoltTheme.gold.opacity(0.12))
                        .frame(width: 80, height: 80)

                    Image(systemName: "airplane.circle")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(BoltTheme.gold)
                }

                Text("No trips found")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(BoltTheme.textPrimary)

                Text("We couldn't find any travel plans for \(destination)")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(BoltTheme.textSecondary)
                    .multilineTextAlignment(.center)

                Button(action: onSearch) {
                    HStack(spacing: BoltTheme.spacingXs) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .medium))
                        Text("Search for \(destination)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(BoltTheme.textInverse)
                    .padding(.horizontal, BoltTheme.spacingMd)
                    .padding(.vertical, BoltTheme.spacingSm)
                    .background(BoltTheme.gold)
                    .clipShape(Capsule())
                }
            }
        }
    }
}

// MARK: - Bolt Travel Loading State
/// 加载状态
struct BoltTravelLoadingState: View {
    @State private var isAnimating = false

    var body: some View {
        BoltGlassSurface(padding: BoltTheme.spacingXl, cornerRadius: BoltTheme.radiusLg) {
            VStack(spacing: BoltTheme.spacingMd) {
                // Animated plane
                Image(systemName: "airplane")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(BoltTheme.gold)
                    .rotationEffect(.degrees(isAnimating ? 10 : -10))
                    .animation(
                        Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                        value: isAnimating
                    )

                Text("Finding best travel options...")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(BoltTheme.textSecondary)
            }
            .onAppear { isAnimating = true }
        }
    }
}

// MARK: - Preview
#Preview {
    ScrollView {
        VStack(spacing: 24) {
            // Showcase with suggestions
            BoltTravelShowcase(
                intent: TravelIntent(
                    destination: "Dubai, UAE",
                    departureDate: Date(),
                    returnDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()),
                    transportMode: .flight,
                    passengerCount: 2,
                    priceRange: TravelIntent.PriceRange(min: 299, max: 599, currency: "USD"),
                    suggestions: [
                        TravelSuggestion(type: .flight, title: "Emirates EK 302", subtitle: "DXB → SIN", price: "$1,240", rating: 4.8, badge: "Best Value", imageURL: nil, actionTitle: "Select"),
                        TravelSuggestion(type: .hotel, title: "Marina Bay Hotel", subtitle: "Marina District", price: "$280/night", rating: 4.7, badge: "Popular", imageURL: nil, actionTitle: "View"),
                        TravelSuggestion(type: .activity, title: "Desert Safari", subtitle: "Evening tour with BBQ", price: "$89/person", rating: 4.6, badge: "Top Rated", imageURL: nil, actionTitle: "Book"),
                        TravelSuggestion(type: .package, title: "Dubai Getaway", subtitle: "5 nights + flights + transfer", price: "$1,299", rating: 4.8, badge: "Best Seller", imageURL: nil, actionTitle: "View")
                    ]
                ),
                onExploreFlights: {},
                onExploreHotels: {},
                onSelectSuggestion: { _ in }
            )

            // Empty state
            BoltTravelEmptyState(destination: "Paris") {}

            // Loading state
            BoltTravelLoadingState()
        }
        .padding()
    }
    .background(Color(hex: 0x0D0D1A))
}