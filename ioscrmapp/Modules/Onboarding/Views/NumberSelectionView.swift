import SwiftUI

struct NumberSelectionView: View {
    @Environment(\.duTheme) private var theme
    @StateObject private var viewModel: NumberSelectionViewModel

    let onContinue: (NumberSelection) -> Void
    let onBack: () -> Void

    init(
        viewModel: NumberSelectionViewModel,
        onContinue: @escaping (NumberSelection) -> Void,
        onBack: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onContinue = onContinue
        self.onBack = onBack
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                NumberSelectionBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        header(safeTop: proxy.safeAreaInsets.top)
                        PromoBanner()
                        SearchBar(text: viewModel.searchText) { value in
                            viewModel.updateSearchText(value)
                        }
                        NumberCarousel(
                            title: "Premium Numbers",
                            actionTitle: "View All",
                            numbers: viewModel.premiumNumbers,
                            isLoading: viewModel.isLoadingInitial,
                            selectedMsisdn: viewModel.selectedMsisdn,
                            reservingMsisdn: viewModel.reservingMsisdn,
                            onSelect: viewModel.select(_:),
                            onContinue: continueWithSelectedNumber,
                            onLoadMore: { item in viewModel.loadMoreIfNeeded(for: .premium, currentItem: item) }
                        )
                        NumberCarousel(
                            title: "Standard Numbers",
                            actionTitle: "Search",
                            numbers: viewModel.standardNumbers,
                            isLoading: viewModel.isLoadingInitial,
                            selectedMsisdn: viewModel.selectedMsisdn,
                            reservingMsisdn: viewModel.reservingMsisdn,
                            onSelect: viewModel.select(_:),
                            onContinue: continueWithSelectedNumber,
                            onLoadMore: { item in viewModel.loadMoreIfNeeded(for: .standard, currentItem: item) }
                        )
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom, 18) + 28)
                }
            }
        }
        .task {
            viewModel.loadInitialIfNeeded()
        }
        .alert("Number unavailable", isPresented: errorBinding) {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .navigationBarBackButtonHidden(true)
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private func header(safeTop: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 42, height: 42)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                RedBullMobileLogo()
            }

            Text("Numbers")
                .font(.system(size: 40, weight: .heavy, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.top, safeTop + 8)
    }

    private func continueWithSelectedNumber() {
        Task {
            guard let selection = await viewModel.reserveSelectedNumber() else { return }
            onContinue(selection)
        }
    }
}

private struct NumberSelectionBackground: View {
    var body: some View {
        ZStack {
            Color(red: 0.03, green: 0.03, blue: 0.035)
            RadialGradient(
                colors: [Color.red.opacity(0.32), .clear],
                center: .topTrailing,
                startRadius: 40,
                endRadius: 360
            )
            LinearGradient(
                colors: [Color.black.opacity(0.2), Color.black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

private struct RedBullMobileLogo: View {
    var body: some View {
        HStack(spacing: 9) {
            ZStack {
                Circle()
                    .fill(Color(red: 1, green: 0.08, blue: 0.18))
                    .frame(width: 28, height: 28)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 13, weight: .black))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: -1) {
                Text("Red Bull")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                Text("Mobile")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.68))
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct PromoBanner: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.badge")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(Color(red: 1, green: 0.08, blue: 0.18))

            Text("GCC roaming now included with all Elite plans automatically.")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.58))
                .lineLimit(2)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: false)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 72, maxHeight: 78, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }
}

private struct SearchBar: View {
    let text: String
    let onChange: (String) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color(red: 1, green: 0.08, blue: 0.18))

            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text("Search by ending digits")
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.46))
                }

                // The placeholder is rendered separately so both hint text and typed suffixes
                // stay legible on the dark glass field across iOS versions.
                TextField("", text: Binding(get: { text }, set: onChange))
                    .keyboardType(.numberPad)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.96))
                    .accentColor(Color(red: 1, green: 0.08, blue: 0.18))
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 56)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct NumberCarousel: View {
    let title: String
    let actionTitle: String
    let numbers: [NumberInventoryItem]
    let isLoading: Bool
    let selectedMsisdn: String?
    let reservingMsisdn: String?
    let onSelect: (NumberInventoryItem) -> Void
    let onContinue: () -> Void
    let onLoadMore: (NumberInventoryItem) -> Void

    private let cardWidth: CGFloat = 318
    private let cardHeight: CGFloat = 288
    private let cardSpacing: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title)
                    .font(.system(size: 24, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer()

                HStack(spacing: 7) {
                    Text(actionTitle)
                    Image(systemName: actionTitle == "Search" ? "magnifyingglass" : "chevron.right")
                }
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red: 1, green: 0.08, blue: 0.18))
            }

            GeometryReader { proxy in
                let viewportFrame = proxy.frame(in: .global)
                let sidePeekInset = max((proxy.size.width - cardWidth) / 2, 0)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: cardSpacing) {
                        if isLoading {
                            ForEach(0..<3, id: \.self) { _ in
                                NumberCardSkeleton(cardWidth: cardWidth, cardHeight: cardHeight)
                            }
                        } else if numbers.isEmpty {
                            EmptyNumberState()
                        } else {
                            ForEach(numbers) { number in
                                NumberParallaxCard(
                                    number: number,
                                    cardWidth: cardWidth,
                                    cardHeight: cardHeight,
                                    viewportFrame: viewportFrame,
                                    isSelected: selectedMsisdn == number.msisdn,
                                    isLoading: reservingMsisdn == number.msisdn,
                                    onSelect: { onSelect(number) },
                                    onContinue: onContinue
                                )
                                .onAppear {
                                    onLoadMore(number)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, sidePeekInset)
                    .padding(.vertical, 10)
                }
            }
            .frame(height: cardHeight + 22)
        }
    }
}

private struct NumberParallaxCard: View {
    let number: NumberInventoryItem
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let viewportFrame: CGRect
    let isSelected: Bool
    let isLoading: Bool
    let onSelect: () -> Void
    let onContinue: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let itemFrame = proxy.frame(in: .global)
            let distanceRatio = numberCarouselDistanceRatio(
                cardMidX: itemFrame.midX - viewportFrame.minX,
                viewportWidth: viewportFrame.width
            )
            let scaleX = 0.94 + (distanceRatio * 0.06)
            let scaleY = 0.86 + (distanceRatio * 0.14)
            let saturation = 1 - (distanceRatio * 0.44)
            let opacity = 0.64 + (distanceRatio * 0.36)

            // The card follows the home parallax reel: centered cards read brighter and larger,
            // while side cards remain visible but intentionally recede.
            NumberCard(
                number: number,
                isSelected: isSelected,
                isLoading: isLoading,
                focusRatio: distanceRatio,
                cardWidth: cardWidth,
                cardHeight: cardHeight,
                onSelect: onSelect,
                onContinue: onContinue
            )
            .scaleEffect(x: scaleX, y: scaleY, anchor: .center)
            .saturation(saturation)
            .opacity(opacity)
        }
        .frame(width: cardWidth, height: cardHeight + 12)
    }
}

private struct NumberCard: View {
    let number: NumberInventoryItem
    let isSelected: Bool
    let isLoading: Bool
    let focusRatio: CGFloat
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let onSelect: () -> Void
    let onContinue: () -> Void

    private var isAvailable: Bool {
        number.reservationStatus == .available || number.reservationStatus == .lockedByMe
    }

    var body: some View {
        ZStack {
            selectedOuterGlow

            cardPanel

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    if let tier = number.premiumTier {
                        PremiumTierBadge(tier: tier, isSelected: isSelected)
                    } else {
                        StandardBadge(isSelected: isSelected)
                    }

                    Spacer()

                    if isSelected {
                        SelectedCheckmark()
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(number.msisdn)
                        .font(.system(size: 24, weight: .heavy, design: .monospaced))
                        .foregroundStyle(numberForeground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.94)
                        .monospacedDigit()

                    Text(priceText)
                        .font(.system(size: 17, weight: .bold, design: .monospaced))
                        .foregroundColor(isSelected ? Color(red: 1, green: 0.86, blue: 0.54).opacity(0.9) : .white.opacity(0.58))
                }

                Spacer(minLength: 0)

                Button(action: isSelected ? onContinue : onSelect) {
                    HStack(spacing: 10) {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else if isSelected {
                            Image(systemName: number.premiumTier == nil ? "checkmark.circle.fill" : "sparkles")
                        }

                        Text(buttonTitle)
                            .lineLimit(1)
                    }
                    .font(.system(size: 17, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white.opacity(isAvailable ? 0.96 : 0.38))
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(buttonBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(buttonStroke)
                }
                .buttonStyle(.plain)
                .disabled(!isAvailable || isLoading)
            }
            .padding(24)
        }
        .frame(width: cardWidth, height: cardHeight, alignment: .topLeading)
        .contentShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .onTapGesture {
            guard isAvailable, !isSelected, !isLoading else { return }
            onSelect()
        }
        .scaleEffect(isSelected ? 1.015 : 1)
        .animation(.spring(response: 0.34, dampingFraction: 0.82), value: isSelected)
        .animation(.easeOut(duration: 0.18), value: focusRatio)
    }

    private var priceText: String {
        guard !number.isFree else { return "Free" }
        return "\(number.price.description) \(number.currency)"
    }

    private var buttonTitle: String {
        if !isAvailable {
            return number.reservationStatus.rawValue.capitalized
        }
        if isSelected {
            return "Continue"
        }
        return number.category == .premium ? "Reserve Number" : "Select Number"
    }

    private var cardPanel: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(cardBackground)

            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(isSelected ? 0.42 : 1)

            // Selection color is now part of the panel itself, so the chosen state does not
            // disappear behind material blur or carousel saturation changes.
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(selectedPanelGradient)
                .opacity(isSelected ? 1 : 0)

            cardGlassHighlight

            cardStroke
        }
        .shadow(color: Color.black.opacity(0.35), radius: 22, x: 0, y: 16)
    }

    private var selectedOuterGlow: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(Color(red: 1, green: 0.08, blue: 0.18).opacity(0.82), lineWidth: 2.2)
                .blur(radius: 10)
                .padding(-7)

            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .stroke(Color(red: 1, green: 0.78, blue: 0.28).opacity(0.62), lineWidth: 1.6)
                .blur(radius: 18)
                .padding(-14)
        }
        .opacity(isSelected ? 1 : 0)
        .allowsHitTesting(false)
    }

    private var buttonBackground: LinearGradient {
        if isSelected {
            return LinearGradient(
                colors: [
                    Color(red: 1, green: 0.08, blue: 0.18),
                    Color(red: 0.72, green: 0.025, blue: 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [
                Color.white.opacity(0.06),
                Color.white.opacity(0.04)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var buttonStroke: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(isSelected ? Color(red: 1, green: 0.78, blue: 0.28).opacity(0.45) : Color.white.opacity(0.04), lineWidth: 1)
    }

    private var cardBackground: LinearGradient {
        let centerAlpha = 0.13 + (focusRatio * 0.1)
        let trailingAlpha = 0.045 + (focusRatio * 0.09)

        // The horizontal fade is tied to carousel focus: as a card slides away, its right edge
        // becomes lighter and thinner until the next focused card restores the full glass panel.
        return LinearGradient(
            colors: [
                Color.white.opacity(centerAlpha),
                Color(red: 0.35, green: 0.24, blue: 0.11).opacity(0.08 + (focusRatio * 0.08)),
                Color.white.opacity(trailingAlpha)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var selectedPanelGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.68, green: 0.015, blue: 0.065).opacity(0.96),
                Color(red: 0.24, green: 0.035, blue: 0.06).opacity(0.94),
                Color(red: 0.58, green: 0.34, blue: 0.08).opacity(0.74)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var cardGlassHighlight: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.13 + (focusRatio * 0.05)),
                        Color.white.opacity(0.012),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .blendMode(.screen)
    }

    private var cardStroke: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        strokeLeadingColor,
                        Color(red: 1, green: 0.82, blue: 0.46).opacity(isSelected ? 0.82 : 0.34 + (focusRatio * 0.18)),
                        Color.white.opacity(0.06 + (focusRatio * 0.08))
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: isSelected ? 2 : 1.35
            )
    }

    private var strokeLeadingColor: Color {
        if isSelected {
            return Color(red: 1, green: 0.08, blue: 0.18).opacity(1)
        }
        return Color(red: 1, green: 0.86, blue: 0.56).opacity(0.22 + (focusRatio * 0.22))
    }

    private var numberForeground: LinearGradient {
        if isSelected {
            return LinearGradient(
                colors: [
                    Color.white,
                    Color(red: 1, green: 0.83, blue: 0.42),
                    Color(red: 1, green: 0.08, blue: 0.18)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }

        return LinearGradient(
            colors: [
                Color.white.opacity(0.96),
                Color.white.opacity(0.84)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var selectedGlowColor: Color {
        Color(red: 1, green: 0.08, blue: 0.18).opacity(0.18)
    }
}

private struct PremiumTierBadge: View {
    let tier: PremiumNumberTier
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .black))
            Text(tier.displayName.uppercased())
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .tracking(1.2)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(isSelected ? color.opacity(0.52) : color.opacity(0.28), in: Capsule())
        .overlay(
            Capsule()
                .stroke(isSelected ? Color.white.opacity(0.18) : Color.clear, lineWidth: 1)
        )
    }

    private var symbol: String {
        switch tier {
        case .royal:
            return "crown.fill"
        case .elite:
            return "sparkles"
        case .gold:
            return "star.fill"
        case .platinum:
            return "diamond.fill"
        }
    }

    private var color: Color {
        switch tier {
        case .royal:
            return Color(red: 1, green: 0.08, blue: 0.18)
        case .elite:
            return Color(red: 0.55, green: 0.24, blue: 1)
        case .gold:
            return Color(red: 1, green: 0.68, blue: 0.16)
        case .platinum:
            return Color(red: 0.62, green: 0.84, blue: 1)
        }
    }
}

private struct StandardBadge: View {
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "simcard.fill")
            Text("STANDARD")
                .tracking(1.1)
        }
        .font(.system(size: 12, weight: .black, design: .monospaced))
        .foregroundColor(.white.opacity(isSelected ? 0.92 : 0.65))
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(isSelected ? Color(red: 1, green: 0.08, blue: 0.18).opacity(0.36) : Color.white.opacity(0.07), in: Capsule())
        .overlay(
            Capsule()
                .stroke(isSelected ? Color(red: 1, green: 0.78, blue: 0.28).opacity(0.35) : Color.clear, lineWidth: 1)
        )
    }
}

private struct SelectedCheckmark: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 1, green: 0.08, blue: 0.18))
                .frame(width: 30, height: 30)
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .black))
                .foregroundColor(.white)
        }
        .shadow(color: Color(red: 1, green: 0.08, blue: 0.18).opacity(0.42), radius: 10, x: 0, y: 5)
    }
}

private struct NumberCardSkeleton: View {
    let cardWidth: CGFloat
    let cardHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Capsule().fill(Color.white.opacity(0.1)).frame(width: 108, height: 36)
            VStack(alignment: .leading, spacing: 12) {
                Capsule().fill(Color.white.opacity(0.12)).frame(width: 246, height: 28)
                Capsule().fill(Color.white.opacity(0.09)).frame(width: 112, height: 20)
            }
            Spacer()
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .frame(height: 58)
        }
        .padding(24)
        .frame(width: cardWidth, height: cardHeight)
        .background(Color.white.opacity(0.052), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .redacted(reason: .placeholder)
    }
}

private struct EmptyNumberState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color(red: 1, green: 0.08, blue: 0.18))
            Text("No numbers found")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            Text("Try another ending pattern.")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.55))
        }
        .padding(26)
        .frame(width: 318, height: 180, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private func numberCarouselDistanceRatio(cardMidX: CGFloat, viewportWidth: CGFloat) -> CGFloat {
    guard viewportWidth > 0 else { return 0 }

    let distance = abs(cardMidX - (viewportWidth / 2))
    let normalized = min(distance / max(viewportWidth * 0.58, 1), 1)

    // Smoothstep matches the home reel's eased center emphasis without exposing abrupt scale jumps.
    return 1 - (normalized * normalized * (3 - (2 * normalized)))
}

struct NumberSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        NumberSelectionView(
            viewModel: NumberSelectionViewModel(),
            onContinue: { _ in },
            onBack: {}
        )
        .duTheme(mode: .dark)
    }
}
