import SwiftUI

struct MallHomeHighlightCarouselView: View {
    let cards: [MallHomeHighlightCard]
    let containerWidth: CGFloat
    let action: (MallHomeHighlightCard) -> Void

    @GestureState private var dragTranslation: CGFloat = 0
    @State private var selectedIndex = 0

    private let autoScrollTimer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()
    private let selectionAnimation = Animation.spring(response: 0.52, dampingFraction: 0.88)

    var body: some View {
        let cardWidth = min(max(containerWidth - 108, 252), 308)
        let sideOffset = min(max(cardWidth * 0.72, 164), 212)

        return VStack(spacing: DUSpacing.sm) {
            GeometryReader { geometry in
                ZStack(alignment: .top) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                        let position = relativePosition(for: index)

                        // 轮播只渲染当前卡和两侧相邻卡，减少重绘和动画层级。
                        if abs(position) <= 1 {
                            MallHomeHighlightCardView(
                                card: card,
                                relativePosition: position,
                                isFocused: position == 0
                            ) {
                                handleCardTap(at: index)
                            }
                            .frame(width: cardWidth, height: 206)
                            .scaleEffect(scaleFactor(for: position))
                            .opacity(opacity(for: position))
                            .offset(
                                x: horizontalOffset(for: position, sideOffset: sideOffset),
                                y: verticalOffset(for: position)
                            )
                            .zIndex(zIndex(for: position))
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .contentShape(Rectangle())
                .gesture(carouselDragGesture(width: geometry.size.width))
                .animation(selectionAnimation, value: selectedIndex)
                .animation(.interactiveSpring(response: 0.26, dampingFraction: 0.88), value: dragTranslation)
            }
            .frame(height: 208)

            HStack(spacing: DUSpacing.xs) {
                ForEach(cards.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == selectedIndex ? DUTheme.cyan : DUTheme.inkDisabled.opacity(0.28))
                        .frame(width: index == selectedIndex ? 22 : 7, height: 7)
                }
            }
        }
        .onReceive(autoScrollTimer) { _ in
            guard cards.count > 1, dragTranslation == 0 else {
                return
            }

            moveSelection(by: 1)
        }
        .onChange(of: cards.count) { newCount in
            guard newCount > 0 else {
                selectedIndex = 0
                return
            }

            selectedIndex = min(selectedIndex, newCount - 1)
        }
    }

    private func relativePosition(for index: Int) -> Int {
        guard !cards.isEmpty else {
            return 0
        }

        var offset = index - selectedIndex
        let halfCount = cards.count / 2

        if offset > halfCount {
            offset -= cards.count
        } else if offset < -halfCount {
            offset += cards.count
        }

        return offset
    }

    private func horizontalOffset(for position: Int, sideOffset: CGFloat) -> CGFloat {
        CGFloat(position) * sideOffset + (dragTranslation * dragMultiplier(for: position))
    }

    private func verticalOffset(for position: Int) -> CGFloat {
        position == 0 ? 0 : 14
    }

    private func scaleFactor(for position: Int) -> CGFloat {
        position == 0 ? 1 : 0.82
    }

    private func opacity(for position: Int) -> Double {
        position == 0 ? 1 : 0.54
    }

    private func zIndex(for position: Int) -> Double {
        position == 0 ? 2 : 1
    }

    private func dragMultiplier(for position: Int) -> CGFloat {
        position == 0 ? 0.2 : 0.12
    }

    private func handleCardTap(at index: Int) {
        guard cards.indices.contains(index) else {
            return
        }

        if index == selectedIndex {
            action(cards[index])
            return
        }

        withAnimation(selectionAnimation) {
            selectedIndex = index
        }
    }

    private func carouselDragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 14)
            .updating($dragTranslation) { value, state, _ in
                state = value.translation.width
            }
            .onEnded { value in
                guard cards.count > 1 else {
                    return
                }

                let threshold = min(max(width * 0.16, 42), 84)

                if value.translation.width <= -threshold {
                    moveSelection(by: 1)
                } else if value.translation.width >= threshold {
                    moveSelection(by: -1)
                }
            }
    }

    private func moveSelection(by step: Int) {
        guard !cards.isEmpty else {
            return
        }

        withAnimation(selectionAnimation) {
            selectedIndex = wrappedIndex(selectedIndex + step)
        }
    }

    private func wrappedIndex(_ index: Int) -> Int {
        guard !cards.isEmpty else {
            return 0
        }

        let count = cards.count
        return ((index % count) + count) % count
    }
}

private struct MallHomeHighlightCardView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore

    let card: MallHomeHighlightCard
    let relativePosition: Int
    let isFocused: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: DUSpacing.md) {
                VStack(alignment: .leading, spacing: DUSpacing.md) {
                    Text(card.badge.value(for: languageStore.currentLanguage))
                        .font(.du(11, weight: .bold))
                        .foregroundColor(Color(hex: 0x9A3412))
                        .padding(.horizontal, 10)
                        .frame(height: 24)
                        .background(Color(hex: 0xFFF1E8))
                        .clipShape(Capsule())

                    VStack(alignment: .leading, spacing: DUSpacing.sm) {
                        Text(card.title.value(for: languageStore.currentLanguage))
                            .font(.du(isFocused ? 24 : 20, weight: .bold))
                            .foregroundColor(DUTheme.ink)
                            .lineLimit(2)

                        Text(card.subtitle.value(for: languageStore.currentLanguage))
                            .font(.du(12, weight: .medium))
                            .foregroundColor(DUTheme.inkSecondary)
                            .lineLimit(isFocused ? 3 : 2)
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        Text(buttonTitle)
                            .font(.du(12, weight: .bold))

                        Image(systemName: "chevron.right")
                            .font(.du(11, weight: .bold))
                    }
                    .foregroundColor(Color(hex: 0xFF6D77))
                }
                .padding(.leading, DUSpacing.lg)
                .padding(.top, DUSpacing.md)
                .padding(.bottom, DUSpacing.md)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

                MallPromotionalIllustration(
                    image: card.image,
                    cornerRadius: 22,
                    contentMode: .fill,
                    contentScale: 1.28
                )
                .frame(width: isFocused ? 128 : 112, height: isFocused ? 128 : 112)
                .padding(.top, DUSpacing.md - 2)
                .padding(.trailing, DUSpacing.lg)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.black.opacity(isFocused ? 0.06 : 0.04), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(
                color: Color.black.opacity(isFocused ? 0.16 : 0.08),
                radius: isFocused ? 22 : 14,
                x: 0,
                y: isFocused ? 16 : 10
            )
            .rotation3DEffect(
                .degrees(rotationDegrees),
                axis: (x: 0.12, y: 1, z: 0),
                anchor: relativePosition >= 0 ? .leading : .trailing,
                perspective: 0.82
            )
        }
        .buttonStyle(.plain)
    }

    private var rotationDegrees: Double {
        switch relativePosition {
        case ..<0:
            return 24
        case 1...:
            return -24
        default:
            return 0
        }
    }

    private var buttonTitle: String {
        switch languageStore.currentLanguage {
        case .simplifiedChinese:
            return "立即抢购"
        case .english:
            return "Shop now"
        case .arabic:
            return "تسوّق الآن"
        }
    }
}

struct MallPromotionalIllustration: View {
    enum ContentMode {
        case fit
        case fill
    }

    let image: MallImageSource
    let cornerRadius: CGFloat
    var contentMode: ContentMode = .fill
    var contentInset: CGFloat = 0
    var contentScale: CGFloat = 1

    var body: some View {
        Group {
            switch image {
            case let .asset(name):
                bitmapView(
                    Image(name)
                        .renderingMode(.original)
                )
            case let .system(name, backgroundHex, tintHex):
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(hex: backgroundHex))
                    .overlay(
                        Image(systemName: name)
                            .font(.du(30, weight: .semibold))
                            .foregroundColor(Color(hex: tintHex))
                    )
            case let .remote(url):
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        bitmapView(image)
                    default:
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color(hex: 0xEEF4FA))
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.du(24, weight: .semibold))
                                    .foregroundColor(Color(hex: 0x7B8CA8))
                            )
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    @ViewBuilder
    private func bitmapView(_ image: Image) -> some View {
        switch contentMode {
        case .fit:
            image
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(contentInset)
        case .fill:
            // 运营海报优先铺满固定图片框，宁可裁边也不保留大面积留白。
            image
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(contentInset)
                .scaleEffect(contentScale)
                .clipped()
        }
    }
}
