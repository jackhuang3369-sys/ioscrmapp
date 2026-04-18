import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct HomeParallaxCarouselView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    let items: [HomeFeatureCarouselItem]
    let onSelectItem: (HomeFeatureCarouselItem) -> Void
    @Binding var isParentScrollLocked: Bool

    @State private var settledIndex = 0
    @State private var dragTranslation: CGFloat = 0
    @State private var isDraggingHorizontally = false

    var body: some View {
        if items.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: 0) {
                GeometryReader { proxy in
                    let metrics = HomeParallaxCarouselMetrics(
                        containerWidth: proxy.size.width,
                        visualDirection: layoutDirection == .rightToLeft ? -1 : 1,
                        reduceMotion: accessibilityReduceMotion
                    )
                    let focusedItem = focusedItem(metrics: metrics)

                    ZStack {
                        ForEach(visibleLayouts(metrics: metrics)) { layout in
                            let item = items[layout.itemIndex]
                            let effect = metrics.effect(for: layout.position)

                            HomeParallaxCarouselCardUnitView(
                                assetName: item.assetName,
                                title: localized(item.title),
                                subtitle: nil,
                                effect: effect,
                                captionWidth: metrics.captionWidth,
                                captionSpacing: metrics.captionTopSpacing,
                                captionOpacity: captionOpacity(for: layout.position)
                            )
                            .offset(x: metrics.offsetX(for: layout.position))
                            .zIndex(effect.zIndex)
                            .opacity(effect.opacity)
                            .accessibilityHidden(layout.itemIndex != focusedIndex(metrics: metrics))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .contentShape(Rectangle())
                    .clipped()
                    .overlay {
                        carouselInteractionOverlay(
                            metrics: metrics,
                            focusedItem: focusedItem
                        )
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(localized(focusedItem?.title))
                    .accessibilityValue("\(focusedIndex(metrics: metrics) + 1) / \(items.count)")
                    .accessibilityAdjustableAction { direction in
                        switch direction {
                        case .increment:
                            settle(to: min(selectedIndex + 1, items.count - 1))
                        case .decrement:
                            settle(to: max(selectedIndex - 1, 0))
                        @unknown default:
                            break
                        }
                    }
                }
                .frame(height: 382)
            }
            .onChange(of: items.count) { newCount in
                guard newCount > 0 else {
                    settledIndex = 0
                    dragTranslation = 0
                    isParentScrollLocked = false
                    return
                }

                settledIndex = min(settledIndex, newCount - 1)
            }
            .onDisappear {
                isParentScrollLocked = false
            }
        }
    }

    @ViewBuilder
    private func carouselInteractionOverlay(
        metrics: HomeParallaxCarouselMetrics,
        focusedItem: HomeFeatureCarouselItem?
    ) -> some View {
#if canImport(UIKit)
        if items.count > 1 {
            HomeParallaxCarouselPanGestureOverlay(
                onChanged: { translation in
                    handleHorizontalDragChanged(translation, metrics: metrics)
                },
                onEnded: { translation, velocity in
                    handleHorizontalDragEnded(
                        translation,
                        velocity: velocity,
                        metrics: metrics
                    )
                },
                onCancelled: {
                    cancelHorizontalDrag()
                },
                onTap: {
                    if let focusedItem {
                        onSelectItem(focusedItem)
                    }
                }
            )
        } else {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    if let focusedItem {
                        onSelectItem(focusedItem)
                    }
                }
        }
#else
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture {
                if let focusedItem {
                    onSelectItem(focusedItem)
                }
            }
#endif
    }

    private var selectedIndex: Int {
        min(max(settledIndex, 0), max(items.count - 1, 0))
    }

    private var selectedItem: HomeFeatureCarouselItem? {
        guard items.indices.contains(selectedIndex) else {
            return nil
        }
        return items[selectedIndex]
    }

    private func focusedIndex(metrics: HomeParallaxCarouselMetrics) -> Int {
        guard !items.isEmpty else {
            return 0
        }

        let rawIndex = CGFloat(selectedIndex) - metrics.translationProgress(for: dragTranslation)
        let nearestIndex = Int(rawIndex.rounded())
        return min(max(nearestIndex, 0), items.count - 1)
    }

    private func focusedItem(
        metrics: HomeParallaxCarouselMetrics
    ) -> HomeFeatureCarouselItem? {
        guard items.indices.contains(focusedIndex(metrics: metrics)) else {
            return nil
        }

        return items[focusedIndex(metrics: metrics)]
    }

    private func visibleLayouts(metrics: HomeParallaxCarouselMetrics) -> [HomeParallaxCarouselLayout] {
        let progressShift = metrics.translationProgress(for: dragTranslation)

        return items.indices
            .map { index in
                HomeParallaxCarouselLayout(
                    itemIndex: index,
                    position: CGFloat(index - selectedIndex) + progressShift
                )
            }
            .filter { abs($0.position) <= 2.4 }
            .sorted { left, right in
                let leftDistance = abs(left.position)
                let rightDistance = abs(right.position)

                if leftDistance == rightDistance {
                    return left.position < right.position
                }

                return leftDistance > rightDistance
            }
    }

    private func captionOpacity(for position: CGFloat) -> Double {
        let distance = abs(position)

        if distance <= 0.08 {
            return 1
        }

        if distance >= 1 {
            return 0
        }

        let fadeProgress = smoothStep((distance - 0.08) / 0.92)
        return Double(1 - fadeProgress)
    }

    private func handleHorizontalDragChanged(
        _ translation: CGSize,
        metrics: HomeParallaxCarouselMetrics
    ) {
        guard items.count > 1 else {
            isParentScrollLocked = false
            return
        }

        isDraggingHorizontally = true
        isParentScrollLocked = true
        dragTranslation = metrics.dampedTranslation(
            translation.width,
            settledIndex: selectedIndex,
            itemCount: items.count
        )
    }

    private func handleHorizontalDragEnded(
        _ translation: CGSize,
        velocity: CGSize,
        metrics: HomeParallaxCarouselMetrics
    ) {
        guard isDraggingHorizontally else {
            isParentScrollLocked = false
            return
        }

        let resolvedTranslation = metrics.dampedTranslation(
            translation.width,
            settledIndex: selectedIndex,
            itemCount: items.count
        )
        // UIKit 没有直接给 predictedEndTranslation，这里用速度近似投影末端落点。
        let projectedTranslation = translation.width + (velocity.width * 0.18)
        let resolvedPredictedTranslation = metrics.dampedTranslation(
            projectedTranslation,
            settledIndex: selectedIndex,
            itemCount: items.count
        )
        let targetIndex = resolvedTargetIndex(
            metrics: metrics,
            translation: resolvedTranslation,
            predictedTranslation: resolvedPredictedTranslation
        )

        settle(to: targetIndex)
        isDraggingHorizontally = false
        isParentScrollLocked = false
    }

    private func cancelHorizontalDrag() {
        guard isDraggingHorizontally else {
            isParentScrollLocked = false
            return
        }

        withAnimation(.easeOut(duration: 0.18)) {
            dragTranslation = 0
        }
        isDraggingHorizontally = false
        isParentScrollLocked = false
    }

    private func resolvedTargetIndex(
        metrics: HomeParallaxCarouselMetrics,
        translation: CGFloat,
        predictedTranslation: CGFloat
    ) -> Int {
        let dragProgress = metrics.translationProgress(for: translation)
        let predictedProgress = metrics.translationProgress(for: predictedTranslation)
        let velocityProgress = predictedProgress - dragProgress
        // 惯性增强系数：越大，松手后越容易顺着速度吸到相邻卡。
        let inertiaBoost = min(0.9, 0.55 + (abs(velocityProgress) * 0.35))
        let projectedProgress = dragProgress + (velocityProgress * inertiaBoost)
        let projectedIndex = CGFloat(selectedIndex) - projectedProgress
        let nearestIndex = Int(projectedIndex.rounded())
        let limitedIndex = min(max(nearestIndex, selectedIndex - 1), selectedIndex + 1)

        return min(max(limitedIndex, 0), items.count - 1)
    }

    private func settle(to targetIndex: Int) {
        withAnimation(
            accessibilityReduceMotion
                ? .easeOut(duration: 0.3)
                // `response` 越大越慢，`dampingFraction` 越大阻尼越强，`blendDuration` 越大收束越柔。
                : .interactiveSpring(response: 0.62, dampingFraction: 0.94, blendDuration: 0.26)
        ) {
            settledIndex = targetIndex
            dragTranslation = 0
        }
    }

    private func localized(_ key: String) -> String {
        languageStore.string(key)
    }

    private func localized(_ value: LocalizedTextValue?) -> String {
        languageStore.string(value)
    }

    private func smoothStep(_ value: CGFloat) -> CGFloat {
        let clampedValue = min(max(value, 0), 1)
        return clampedValue * clampedValue * (3 - (2 * clampedValue))
    }
}

#if canImport(UIKit)
private struct HomeParallaxCarouselPanGestureOverlay: UIViewRepresentable {
    let onChanged: (CGSize) -> Void
    let onEnded: (CGSize, CGSize) -> Void
    let onCancelled: () -> Void
    let onTap: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onChanged: onChanged,
            onEnded: onEnded,
            onCancelled: onCancelled,
            onTap: onTap
        )
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear

        let recognizer = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        recognizer.delegate = context.coordinator
        recognizer.cancelsTouchesInView = true
        view.addGestureRecognizer(recognizer)
        context.coordinator.recognizer = recognizer

        let tapRecognizer = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        tapRecognizer.delegate = context.coordinator
        tapRecognizer.require(toFail: recognizer)
        view.addGestureRecognizer(tapRecognizer)
        context.coordinator.tapRecognizer = tapRecognizer

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
        context.coordinator.onCancelled = onCancelled
        context.coordinator.onTap = onTap
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onChanged: (CGSize) -> Void
        var onEnded: (CGSize, CGSize) -> Void
        var onCancelled: () -> Void
        var onTap: () -> Void
        weak var recognizer: UIPanGestureRecognizer?
        weak var tapRecognizer: UITapGestureRecognizer?

        init(
            onChanged: @escaping (CGSize) -> Void,
            onEnded: @escaping (CGSize, CGSize) -> Void,
            onCancelled: @escaping () -> Void,
            onTap: @escaping () -> Void
        ) {
            self.onChanged = onChanged
            self.onEnded = onEnded
            self.onCancelled = onCancelled
            self.onTap = onTap
        }

        @objc
        func handlePan(_ recognizer: UIPanGestureRecognizer) {
            guard let view = recognizer.view else {
                return
            }

            let translation = recognizer.translation(in: view)
            let velocity = recognizer.velocity(in: view)

            switch recognizer.state {
            case .began, .changed:
                onChanged(CGSize(width: translation.x, height: translation.y))
            case .ended:
                onEnded(
                    CGSize(width: translation.x, height: translation.y),
                    CGSize(width: velocity.x, height: velocity.y)
                )
            case .cancelled, .failed:
                onCancelled()
            default:
                break
            }
        }

        @objc
        func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended else {
                return
            }

            onTap()
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer is UITapGestureRecognizer {
                return true
            }

            guard
                let panGestureRecognizer = gestureRecognizer as? UIPanGestureRecognizer,
                let view = panGestureRecognizer.view
            else {
                return true
            }

            let velocity = panGestureRecognizer.velocity(in: view)
            return abs(velocity.x) > abs(velocity.y)
        }
    }
}
#endif

private struct HomeParallaxCarouselCaptionView: View {
    @Environment(\.duTheme) private var theme

    let title: String
    let subtitle: String?

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.du(16, weight: .semibold))
                .foregroundColor(theme.colors.text.primary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.88)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.du(12, weight: .medium))
                    .foregroundColor(theme.colors.text.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct HomeParallaxCarouselCardUnitView: View {
    let assetName: String
    let title: String
    let subtitle: String?
    let effect: HomeParallaxCarouselCardEffect
    let captionWidth: CGFloat
    let captionSpacing: CGFloat
    let captionOpacity: Double

    var body: some View {
        VStack(spacing: captionSpacing) {
            HomeParallaxCarouselCardView(
                assetName: assetName,
                effect: effect
            )

            HomeParallaxCarouselCaptionView(
                title: title,
                subtitle: subtitle
            )
            .frame(width: captionWidth)
            .opacity(captionOpacity)
        }
        .frame(width: max(effect.cardSize.width, captionWidth))
    }
}

private struct HomeParallaxCarouselCardView: View {
    @Environment(\.duTheme) private var theme

    let assetName: String
    let effect: HomeParallaxCarouselCardEffect

    var body: some View {
        let baseFill = theme.resolvedColorScheme == .dark
            ? theme.colors.surface.raised.opacity(0.66)
            : Color.black.opacity(0.08)
        let borderColor = theme.resolvedColorScheme == .dark
            ? theme.colors.border.default.opacity(0.86)
            : Color.white.opacity(0.68)

        ZStack {
            RoundedRectangle(cornerRadius: effect.cornerRadius, style: .continuous)
                .fill(baseFill)

            // Card and image move in the same screen-space direction. The local counter-shift
            // inside the viewport makes the background feel slower than the foreground card.
            Image(assetName)
                .renderingMode(.original)
                .resizable()
                .scaledToFill()
                .frame(
                    width: effect.imageCanvasWidth,
                    height: effect.imageCanvasHeight
                )
                .scaleEffect(effect.imageScale)
                .offset(x: effect.backgroundOffset)
                .frame(width: effect.cardSize.width, height: effect.cardSize.height)
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.clear,
                            Color.black.opacity(0.22)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipped()
        }
        .frame(width: effect.cardSize.width, height: effect.cardSize.height)
        .clipShape(RoundedRectangle(cornerRadius: effect.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: effect.cornerRadius, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .shadow(
            color: Color.black.opacity(effect.shadowOpacity),
            radius: effect.shadowRadius,
            x: 0,
            y: effect.shadowYOffset
        )
        .rotation3DEffect(
            .degrees(effect.rotationDegrees),
            axis: (x: 0.14, y: 1, z: 0),
            anchor: effect.rotationDegrees < 0 ? .trailing : .leading,
            perspective: 0.92
        )
    }
}

private struct HomeParallaxCarouselLayout: Identifiable {
    let itemIndex: Int
    let position: CGFloat

    var id: Int {
        itemIndex
    }
}

private struct HomeParallaxCarouselCardEffect {
    let cardSize: CGSize
    let scale: CGFloat
    let opacity: Double
    let zIndex: Double
    let yOffset: CGFloat
    let rotationDegrees: Double
    let backgroundOffset: CGFloat
    let imageCanvasWidth: CGFloat
    let imageCanvasHeight: CGFloat
    let imageScale: CGFloat
    let cornerRadius: CGFloat
    let shadowOpacity: CGFloat
    let shadowRadius: CGFloat
    let shadowYOffset: CGFloat
}

private struct HomeParallaxCarouselMetrics {
    let visualDirection: CGFloat
    let centerCardWidth: CGFloat
    let sideCardWidth: CGFloat
    let centerCardHeight: CGFloat
    let sideCardHeight: CGFloat
    let interCardSpacing: CGFloat
    let sideCardReferenceScale: CGFloat
    let itemSpan: CGFloat
    let imageCanvasBaseWidth: CGFloat
    let imageCanvasBaseHeight: CGFloat
    let imageOverflowWidth: CGFloat
    let imageOverflowHeight: CGFloat
    let maxRotationDegrees: Double
    let centerYOffset: CGFloat
    let backgroundTravelMultiplier: CGFloat
    let captionWidth: CGFloat
    let captionTopSpacing: CGFloat
    let cornerRadius: CGFloat = 28

    init(containerWidth: CGFloat, visualDirection: CGFloat, reduceMotion: Bool) {
        // 两侧侧卡的露出宽度；增大后左右会露出更多内容。
        let targetSidePeekWidth = min(max(containerWidth * 0.152, 45.6), 55.1)
        // 主卡与侧卡之间的实际缝隙；越小越紧凑。
        let resolvedInterCardSpacing: CGFloat = 1.5
        let preferredCenterWidth = containerWidth - ((targetSidePeekWidth + resolvedInterCardSpacing) * 2)
        // 主卡窗口宽度；减小后侧卡露出会更明显。
        let resolvedCenterWidth = min(
            max(preferredCenterWidth, 224),
            min(containerWidth - 76, 272)
        )
        let resolvedSideWidth = resolvedCenterWidth * 0.94
        let baseHeight = resolvedCenterWidth * 0.74
        // 侧卡高度基准；增大后主副卡高低差更明显。
        let resolvedSideHeight = baseHeight * 1.42
        // 主卡相对侧卡的高度比例；增大后主卡更高。
        let resolvedCenterHeight = resolvedSideHeight * 0.756
        // 侧卡额外缩放；大于 1 会让侧卡稍微更“撑开”。
        let resolvedSideCardReferenceScale: CGFloat = 1.03
        let separatedItemSpan =
            (resolvedCenterWidth / 2) +
            ((resolvedSideWidth * resolvedSideCardReferenceScale) / 2) +
            resolvedInterCardSpacing

        self.visualDirection = visualDirection
        centerCardWidth = resolvedCenterWidth
        sideCardWidth = resolvedSideWidth
        centerCardHeight = resolvedCenterHeight
        sideCardHeight = resolvedSideHeight
        interCardSpacing = resolvedInterCardSpacing
        sideCardReferenceScale = resolvedSideCardReferenceScale
        itemSpan = separatedItemSpan
        // 图片基础溢出宽度；增大后可提供更大的横向 Parallax 位移空间。
        imageOverflowWidth = resolvedCenterWidth * 0.96
        imageOverflowHeight = resolvedCenterHeight * 0.22
        imageCanvasBaseWidth = max(resolvedCenterWidth, resolvedSideWidth) + imageOverflowWidth
        imageCanvasBaseHeight = max(resolvedCenterHeight, resolvedSideHeight) + imageOverflowHeight
        maxRotationDegrees = reduceMotion ? 0 : 8
        centerYOffset = 0
        // 图片内部反向补偿倍率；越大，前后速度差越明显。
        backgroundTravelMultiplier = reduceMotion ? 0 : 0.87
        captionWidth = resolvedCenterWidth
        captionTopSpacing = 10
    }

    func translationProgress(for translation: CGFloat) -> CGFloat {
        guard itemSpan > 0 else {
            return 0
        }

        return (translation / itemSpan) * visualDirection
    }

    func dampedTranslation(
        _ translation: CGFloat,
        settledIndex: Int,
        itemCount: Int
    ) -> CGFloat {
        guard itemCount > 1 else {
            return 0
        }

        let edgeTranslation = translation * visualDirection
        let isDraggingBeyondFirstItem = settledIndex == 0 && edgeTranslation > 0
        let isDraggingBeyondLastItem = settledIndex == itemCount - 1 && edgeTranslation < 0

        guard isDraggingBeyondFirstItem || isDraggingBeyondLastItem else {
            return translation
        }

        return translation * 0.28
    }

    func offsetX(for position: CGFloat) -> CGFloat {
        position * itemSpan * visualDirection
    }

    func effect(for position: CGFloat) -> HomeParallaxCarouselCardEffect {
        let clampedPosition = min(max(position, -2.2), 2.2)
        let primaryDistance = min(abs(clampedPosition), 1)
        let sideProgress = smoothStep(primaryDistance)
        let offscreenProgress = smoothStep(min(max(abs(clampedPosition) - 1, 0), 1))
        let cardWidth = mix(centerCardWidth, sideCardWidth, sideProgress)
        let cardHeight = mix(centerCardHeight, sideCardHeight, sideProgress)
        let opacity = mix(1, 0.74, sideProgress) * mix(1, 0.24, offscreenProgress)
        let rotationDegrees = Double(-clampedPosition) * maxRotationDegrees
        let yOffset = mix(centerYOffset, 0, sideProgress) + (offscreenProgress * 14)
        // 中心区域额外位移差；越大，主卡附近的 Parallax 更明显。
        let backgroundLeadMultiplier = backgroundTravelMultiplier + ((1 - sideProgress) * 0.224)
        let backgroundOffset = -clampedPosition * itemSpan * backgroundLeadMultiplier
        let dynamicCanvasWidth = imageCanvasBaseWidth
        let dynamicCanvasHeight = imageCanvasBaseHeight

        return HomeParallaxCarouselCardEffect(
            cardSize: CGSize(width: cardWidth, height: cardHeight),
            scale: 1,
            opacity: Double(opacity),
            zIndex: Double(10 - abs(clampedPosition)),
            yOffset: yOffset,
            rotationDegrees: rotationDegrees,
            backgroundOffset: backgroundOffset,
            imageCanvasWidth: dynamicCanvasWidth,
            imageCanvasHeight: dynamicCanvasHeight,
            imageScale: 1,
            cornerRadius: cornerRadius,
            shadowOpacity: mix(0.2, 0.08, sideProgress) * mix(1, 0.3, offscreenProgress),
            shadowRadius: mix(22, 12, sideProgress),
            shadowYOffset: mix(18, 8, sideProgress)
        )
    }

    private func smoothStep(_ value: CGFloat) -> CGFloat {
        let clampedValue = min(max(value, 0), 1)
        return clampedValue * clampedValue * (3 - (2 * clampedValue))
    }

    private func mix(_ from: CGFloat, _ to: CGFloat, _ progress: CGFloat) -> CGFloat {
        from + ((to - from) * progress)
    }
}
