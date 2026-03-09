import SwiftUI

struct HomeView: View {
    let session: UserSession
    @ObservedObject var sessionStore: SessionStore
    @State private var placeholderMessage: String?

    private let quickActions: [HomeItem] = [
        .init(title: "Recharge", icon: "creditcard.fill"),
        .init(title: "Plans", icon: "shippingbox.fill"),
        .init(title: "Offers", icon: "gift.fill"),
        .init(title: "Mall", icon: "cart.fill")
    ]

    private let services: [HomeItem] = [
        .init(title: "Data Pack", icon: "antenna.radiowaves.left.and.right"),
        .init(title: "Voice Pack", icon: "phone.fill"),
        .init(title: "Roaming", icon: "globe.europe.africa.fill"),
        .init(title: "Coupons", icon: "ticket.fill"),
        .init(title: "Bills", icon: "chart.bar.fill"),
        .init(title: "Points", icon: "star.circle.fill"),
        .init(title: "Video", icon: "play.tv.fill"),
        .init(title: "Support", icon: "person.wave.2.fill")
    ]

    private let products: [HomeProduct] = [
        .init(name: "iPhone 15 Pro Max 256GB", price: "AED 5,999", oldPrice: "AED 6,999", icon: "iphone"),
        .init(name: "AirPods Pro 2", price: "AED 1,299", oldPrice: nil, icon: "airpodspro"),
        .init(name: "Apple Watch S9", price: "AED 2,499", oldPrice: nil, icon: "applewatch")
    ]

    private let usageItems: [UsageItem] = [
        .init(title: "Data", value: "8.5 / 10 GB", progress: 0.85),
        .init(title: "Voice", value: "156 / 200 min", progress: 0.78),
        .init(title: "SMS", value: "45 / 50", progress: 0.90)
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: DUSpacing.lg) {
                    header
                    quickActionsSection
                    banner
                    servicesSection
                    productsSection
                    Spacer(minLength: 92)
                }
                .padding(.bottom, DUSpacing.xxxl)
            }
            .background(DUTheme.background.ignoresSafeArea())

            tabBar
        }
        .alert(isPresented: placeholderAlertIsPresented) {
            Alert(
                title: Text("Coming Soon"),
                message: Text(placeholderMessage ?? ""),
                dismissButton: .default(Text("OK")) {
                    placeholderMessage = nil
                }
            )
        }
    }

    private var header: some View {
        VStack(spacing: DUSpacing.lg) {
            HStack {
                HStack(spacing: DUSpacing.md) {
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.white)
                        )
                    VStack(alignment: .leading, spacing: DUSpacing.xs) {
                        Text(session.greeting)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                        Text(session.displayName)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                Spacer()

                HStack(spacing: DUSpacing.sm) {
                    CircleAction(symbol: "magnifyingglass") {
                        placeholderMessage = "Search is coming soon."
                    }
                    CircleAction(symbol: "bell.fill") {
                        placeholderMessage = "Notifications are coming soon."
                    }
                    CircleAction(symbol: "rectangle.portrait.and.arrow.right") {
                        sessionStore.signOut()
                    }
                }
            }

            VStack(spacing: DUSpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: DUSpacing.xs) {
                        Text("Current Balance")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                        Text(session.balanceText)
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Button("Recharge") {
                        placeholderMessage = "Recharge is coming soon."
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DUTheme.ink)
                    .padding(.horizontal, DUSpacing.lg)
                    .frame(height: 36)
                    .background(Color.white.opacity(0.95))
                    .clipShape(Capsule())
                }

                HStack(spacing: DUSpacing.lg) {
                    ForEach(usageItems) { item in
                        VStack(alignment: .leading, spacing: DUSpacing.xs) {
                            Text(item.title)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                            Text(item.value)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                            ProgressView(value: item.progress)
                                .accentColor(.white)
                        }
                    }
                }
            }
            .padding(DUSpacing.lg)
            .background(Color.white.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .padding(.horizontal, DUSpacing.lg)
        .padding(.top, DUSpacing.xxxl + 12)
        .padding(.bottom, DUSpacing.xxxl)
        .background(DUTheme.brandGradient)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .padding(.horizontal, DUSpacing.lg)
        .padding(.top, DUSpacing.lg)
    }

    private var quickActionsSection: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DUSpacing.md), count: 4), spacing: DUSpacing.md) {
            ForEach(quickActions) { item in
                Button {
                    placeholderMessage = "\(item.title) is coming soon."
                } label: {
                    VStack(spacing: DUSpacing.sm) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(DUTheme.backgroundSecondary)
                                .frame(height: 56)
                            Image(systemName: item.icon)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(DUTheme.cyan)
                        }
                        Text(item.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(DUTheme.ink)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DUSpacing.lg)
        .duCardStyle()
        .padding(.horizontal, DUSpacing.lg)
        .offset(y: -24)
        .padding(.bottom, -24)
    }

    private var banner: some View {
        Button {
            placeholderMessage = "Promotions are coming soon."
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: DUSpacing.sm) {
                    Text("🎉 New customer special")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Text("Get 50% extra data on your first recharge. Offer ends in 3 days.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
                Spacer()
            }
            .padding(DUSpacing.xl)
            .background(DUTheme.subtleGradient)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, DUSpacing.lg)
    }

    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: DUSpacing.lg) {
            sectionHeader(title: "Popular Services")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DUSpacing.md), count: 4), spacing: DUSpacing.md) {
                ForEach(services) { item in
                    Button {
                        placeholderMessage = "\(item.title) is coming soon."
                    } label: {
                        VStack(spacing: DUSpacing.sm) {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(DUTheme.backgroundSecondary)
                                .frame(height: 56)
                                .overlay(
                                    Image(systemName: item.icon)
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(DUTheme.blue)
                                )
                            Text(item.title)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(DUTheme.ink)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(DUSpacing.xl)
        .duCardStyle()
        .padding(.horizontal, DUSpacing.lg)
    }

    private var productsSection: some View {
        VStack(alignment: .leading, spacing: DUSpacing.lg) {
            sectionHeader(title: "🔥 Trending Products")

            VStack(spacing: DUSpacing.md) {
                ForEach(products) { product in
                    Button {
                        placeholderMessage = "\(product.name) details are coming soon."
                    } label: {
                        HStack(spacing: DUSpacing.lg) {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(DUTheme.backgroundSecondary)
                                .frame(width: 72, height: 72)
                                .overlay(
                                    Image(systemName: product.icon)
                                        .font(.system(size: 28, weight: .medium))
                                        .foregroundColor(DUTheme.magenta)
                                )

                            VStack(alignment: .leading, spacing: DUSpacing.sm) {
                                Text(product.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(DUTheme.ink)
                                    .multilineTextAlignment(.leading)
                                HStack(spacing: DUSpacing.sm) {
                                    Text(product.price)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(DUTheme.cyan)
                                    if let oldPrice = product.oldPrice {
                                        Text(oldPrice)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(DUTheme.inkDisabled)
                                            .overlay(
                                                Rectangle()
                                                    .fill(DUTheme.inkDisabled)
                                                    .frame(height: 1)
                                            )
                                    }
                                }
                            }

                            Spacer()
                        }
                        .padding(DUSpacing.lg)
                        .background(DUTheme.backgroundSecondary.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(DUSpacing.xl)
        .duCardStyle()
        .padding(.horizontal, DUSpacing.lg)
    }

    private var tabBar: some View {
        HStack {
            TabItem(symbol: "house.fill", title: "Home", isActive: true) {}
            TabItem(symbol: "cart.fill", title: "Mall", isActive: false) {
                placeholderMessage = "Mall is coming soon."
            }
            TabItem(symbol: "play.tv.fill", title: "Video", isActive: false) {
                placeholderMessage = "Video is coming soon."
            }
            TabItem(symbol: "ticket.fill", title: "Tickets", isActive: false) {
                placeholderMessage = "Tickets are coming soon."
            }
            TabItem(symbol: "person.fill", title: "Profile", isActive: false) {
                placeholderMessage = "Profile is coming soon."
            }
        }
        .padding(.horizontal, DUSpacing.lg)
        .padding(.top, DUSpacing.md)
        .padding(.bottom, DUSpacing.lg)
        .background(DUTheme.panel.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding(.horizontal, DUSpacing.lg)
        .padding(.bottom, DUSpacing.lg)
    }

    private func sectionHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(DUTheme.ink)
            Spacer()
            Button("View all") {
                placeholderMessage = "\(title) is coming soon."
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(DUTheme.cyan)
        }
    }

    private var placeholderAlertIsPresented: Binding<Bool> {
        Binding(
            get: { placeholderMessage != nil },
            set: { isPresented in
                if !isPresented {
                    placeholderMessage = nil
                }
            }
        )
    }
}

private struct HomeItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
}

private struct HomeProduct: Identifiable {
    let id = UUID()
    let name: String
    let price: String
    let oldPrice: String?
    let icon: String
}

private struct UsageItem: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let progress: Double
}

private struct CircleAction: View {
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(.white.opacity(0.16))
                .frame(width: 38, height: 38)
                .overlay(
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct TabItem: View {
    let symbol: String
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DUSpacing.xs) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(isActive ? DUTheme.cyan : DUTheme.inkTertiary)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(
            session: UserSession(
                displayName: "Ahmed Mohammed",
                phoneNumber: AuthValidator.demoPhone,
                greeting: "Good Morning",
                balanceText: "128.50 AED"
            ),
            sessionStore: SessionStore.previewAuthenticated
        )
    }
}
