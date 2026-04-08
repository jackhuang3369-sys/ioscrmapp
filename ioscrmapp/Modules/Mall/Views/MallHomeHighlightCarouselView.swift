import SwiftUI

struct MallHomeHighlightCarouselView: View {
    let cards: [MallHomeHighlightCard]
    let containerWidth: CGFloat
    let action: (MallHomeHighlightCard) -> Void

    @GestureState private var dragTranslation: CGFloat = 0
    @State private var carouselPosition = 0
    @State private var isAutoScrollPaused = false
    @State private var autoScrollResumeDate = Date.distantPast

    private let selectionAnimation = Animation.interactiveSpring(
        response: 0.68, //值越大，动画整体越慢、越从容。
        dampingFraction: 0.88, //越小，弹性越明显，容易有一点晃动或回弹感
        blendDuration: 0.24 //它通常不是决定“快慢”的第一参数，更多是调顺滑感。
    )
    private let dragAnimation = Animation.interactiveSpring(
        response: 0.30,
        dampingFraction: 0.90,
        blendDuration: 0.18
    )
    private let autoScrollTimer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    var body: some View {
        let cardWidth = min(max(containerWidth - 72, 284), 332)
        let cardHeight = min(max(cardWidth * 0.72, 214), 246)
        let cardSpacing = min(max(cardWidth * 0.22, 68), 92)
        let swipeThreshold = min(max(cardWidth * 0.24, 78), 98)
        let carouselHeight = cardHeight + 18

        return GeometryReader { geometry in
            let screenWidth = geometry.size.width

            ZStack {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    let progress = relativeProgress(
                        for: index,
                        cardWidth: cardWidth,
                        cardSpacing: cardSpacing
                    )
                    let absoluteProgress = abs(progress)

                    MallHomeHighlightCardView(
                        card: card,
                        progress: progress,
                        cardWidth: cardWidth,
                        cardHeight: cardHeight
                    ) {
                        handleCardTap(at: index)
                    }
                    .scaleEffect(cardScale(for: absoluteProgress))
                    .rotation3DEffect(
                        .degrees(cardRotation(for: progress)),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.85
                    )
                    .offset(x: horizontalOffset(for: progress, cardWidth: cardWidth))
                    .offset(y: verticalOffset(for: absoluteProgress))
                    .opacity(opacity(for: absoluteProgress))
                    .zIndex(zIndex(for: absoluteProgress, index: index))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 8)
                    .updating($dragTranslation) { value, state, _ in
                        state = value.translation.width
                    }
                    .onChanged { _ in
                        isAutoScrollPaused = true
                    }
                    .onEnded { value in
                        handleDragEnded(
                            value: value,
                            screenWidth: screenWidth,
                            swipeThreshold: swipeThreshold
                        )
                        isAutoScrollPaused = false
                        deferAutoScroll()
                    }
            )
            .animation(selectionAnimation, value: carouselPosition)
            .animation(dragAnimation, value: dragTranslation)
            .onReceive(autoScrollTimer) { _ in
                guard
                    cards.count > 1,
                    dragTranslation == 0,
                    !isAutoScrollPaused,
                    Date() >= autoScrollResumeDate
                else {
                    return
                }

                withAnimation(selectionAnimation) {
                    carouselPosition += 1
                }
            }
        }
        .frame(height: carouselHeight)
        .onChange(of: cards.count) { newCount in
            guard newCount > 0 else {
                carouselPosition = 0
                return
            }

            carouselPosition = normalizedIndex(for: carouselPosition)
        }
    }

    private func normalizedIndex(for position: Int) -> Int {
        guard !cards.isEmpty else {
            return 0
        }

        let remainder = position % cards.count
        return remainder >= 0 ? remainder : remainder + cards.count
    }

    private func nearestVirtualIndex(for index: Int, around position: Int) -> Int {
        guard !cards.isEmpty else {
            return 0
        }

        let normalizedPosition = normalizedIndex(for: position)
        let baseIndex = position - normalizedPosition + index
        let candidates = [baseIndex, baseIndex - cards.count, baseIndex + cards.count]

        return candidates.min { lhs, rhs in
            let lhsDistance = abs(lhs - position)
            let rhsDistance = abs(rhs - position)

            if lhsDistance != rhsDistance {
                return lhsDistance < rhsDistance
            }

            return (lhs - position) > (rhs - position)
        } ?? baseIndex
    }

    private func deferAutoScroll() {
        autoScrollResumeDate = Date().addingTimeInterval(4.2)
    }

    private func relativeProgress(
        for index: Int,
        cardWidth: CGFloat,
        cardSpacing: CGFloat
    ) -> CGFloat {
        guard !cards.isEmpty else {
            return 0
        }

        let base = CGFloat(nearestVirtualIndex(for: index, around: carouselPosition) - carouselPosition)
        let dragProgress = dragTranslation / (cardWidth + cardSpacing)
        return base + dragProgress
    }

    private func horizontalOffset(for progress: CGFloat, cardWidth: CGFloat) -> CGFloat {
        progress * (cardWidth * 0.72)
    }

    private func verticalOffset(for absoluteProgress: CGFloat) -> CGFloat {
        min(absoluteProgress * 18, 24)
    }

    private func cardScale(for absoluteProgress: CGFloat) -> CGFloat {
        max(0.84, 1 - (absoluteProgress * 0.12))
    }

    private func cardRotation(for progress: CGFloat) -> Double {
        Double(max(-1, min(1, progress))) * -18
    }

    private func opacity(for absoluteProgress: CGFloat) -> Double {
        max(0.45, 1 - (Double(absoluteProgress) * 0.28))
    }

    private func zIndex(for absoluteProgress: CGFloat, index: Int) -> Double {
        let centerPriority = 100 - Double(absoluteProgress * 10)
        return centerPriority + Double(cards.count - index)
    }

    private func handleCardTap(at index: Int) {
        guard cards.indices.contains(index) else {
            return
        }

        deferAutoScroll()

        if index == normalizedIndex(for: carouselPosition) {
            action(cards[index])
            return
        }

        withAnimation(selectionAnimation) {
            carouselPosition = nearestVirtualIndex(for: index, around: carouselPosition)
        }
    }

    private func handleDragEnded(
        value: DragGesture.Value,
        screenWidth: CGFloat,
        swipeThreshold: CGFloat
    ) {
        guard cards.count > 1 else {
            return
        }

        let translation = value.translation.width
        let predictedTranslation = value.predictedEndTranslation.width
        let velocityBoost = min(abs(predictedTranslation - translation), screenWidth * 0.14)
        let effectiveThreshold = max(56, swipeThreshold - (velocityBoost * 0.18))

        let shouldMoveByPrediction = abs(predictedTranslation) > effectiveThreshold
        let shouldMoveByTranslation = abs(translation) > effectiveThreshold

        var newPosition = carouselPosition

        if shouldMoveByPrediction {
            newPosition += predictedTranslation < 0 ? 1 : -1
        } else if shouldMoveByTranslation {
            newPosition += translation < 0 ? 1 : -1
        }

        carouselPosition = newPosition
    }
}

private struct MallHomeHighlightCardView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore

    let card: MallHomeHighlightCard
    let progress: CGFloat
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let action: () -> Void

    private let cornerRadius: CGFloat = 28

    var body: some View {
        let absoluteProgress = abs(progress)
        let clampedProgress = max(-1.2, min(1.2, progress))
        let parallaxOffset = -clampedProgress * 40
        let imageScale = 1.14 - min(absoluteProgress * 0.08, 0.08)
        let shadowOpacity = max(0.12, 0.24 - (Double(absoluteProgress) * 0.08))

        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: card.startHex),
                            Color(hex: card.endHex)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            ZStack {
                GeometryReader { geometry in
                    MallHomeHighlightArtworkView(image: card.image)
                        .frame(
                            width: geometry.size.width + 84,
                            height: geometry.size.height + 6
                        )
                        .scaleEffect(imageScale)
                        .offset(x: parallaxOffset, y: -4)
                }

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.08),
                        Color.clear,
                        Color.black.opacity(0.20),
                        Color.black.opacity(0.66)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

            VStack(alignment: .leading, spacing: DUSpacing.xs) {
                if !resolvedTitle.isEmpty {
                    Text(card.title.value(for: languageStore.currentLanguage))
                        .font(.du(24, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 4)
                }

                if !resolvedSubtitle.isEmpty {
                    Text(card.subtitle.value(for: languageStore.currentLanguage))
                        .font(.du(13, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.84))
                        .lineLimit(2)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.14),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
                .blendMode(.screen)
                .allowsHitTesting(false)
                .padding(1)
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(
            color: Color.black.opacity(shadowOpacity),
            radius: 14,
            x: 0,
            y: 8
        )
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onTapGesture {
            action()
        }
    }

    private var resolvedTitle: String {
        card.title.value(for: languageStore.currentLanguage)
    }

    private var resolvedSubtitle: String {
        card.subtitle.value(for: languageStore.currentLanguage)
    }
}

private struct MallHomeHighlightArtworkView: View {
    let image: MallImageSource

    var body: some View {
        Group {
            switch image {
            case let .asset(name):
                Image(name)
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFill()
            case let .system(name, backgroundHex, tintHex):
                LinearGradient(
                    colors: [
                        Color(hex: backgroundHex),
                        Color(hex: tintHex).opacity(0.72)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay(
                    Image(systemName: name)
                        .font(.du(88, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.9))
                        .shadow(color: Color.black.opacity(0.14), radius: 12, x: 0, y: 8)
                )
            case let .remote(url):
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        ZStack {
                            Color(hex: 0xEEF4FA)

                            Image(systemName: "photo")
                                .font(.du(28, weight: .semibold))
                                .foregroundColor(Color(hex: 0x7B8CA8))
                        }
                    }
                }
            }
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
