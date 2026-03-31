import SwiftUI

/// 首页轮播图的模块内专用实现。
///
/// 实现路径为 `HomeView.featuredCarouselSection -> HomeFeatureCarouselView -> HomeFeatureCarouselCardView`。
/// 当前效果不是靠图片本体的缩放或旋转制造变化，而是让卡片窗口横向滑动，
/// 再让更宽的图片在窗口内部做反向缓慢位移，形成 viewport reveal + parallax crop。
/// 两侧卡片额外叠加灰度、透明度和尺寸差异，用来保留首页当前的层级感。
struct HomeFeatureCarouselView: View {
    let assetNames: [String]

    @State private var settledIndex = 0
    @State private var dragTranslation: CGFloat = 0
    @State private var isDraggingHorizontally = false
    @State private var autoAdvanceCycle = 0

    private let autoAdvanceIntervalNanoseconds: UInt64 = 4_000_000_000

    var body: some View {
        VStack(spacing: DUSpacing.md) {
            GeometryReader { proxy in
                let metrics = HomeFeatureCarouselMetrics(containerWidth: proxy.size.width)

                ZStack {
                    ForEach(visibleLayouts(metrics: metrics)) { layout in
                        carouselCard(
                            assetName: assetNames[layout.assetIndex],
                            layout: layout,
                            metrics: metrics
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .clipped()
                .simultaneousGesture(
                    dragGesture(metrics: metrics)
                )
            }
            .frame(height: 226)

            if assetNames.count > 1 {
                pageIndicator
            }
        }
        .task(id: autoAdvanceCycle) {
            await runAutoAdvanceCycle()
        }
        .onChange(of: assetNames.count) { newCount in
            guard newCount > 0 else {
                settledIndex = 0
                restartAutoAdvanceCycle()
                return
            }

            settledIndex = wrappedIndex(settledIndex, assetCount: newCount)
            restartAutoAdvanceCycle()
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: DUSpacing.xs) {
            ForEach(assetNames.indices, id: \.self) { index in
                Capsule()
                    .fill(
                        index == selectedAssetIndex
                        ? DUTheme.cyan
                        : DUTheme.inkDisabled.opacity(0.35)
                    )
                    .frame(width: index == selectedAssetIndex ? 18 : 6, height: 6)
            }
        }
    }

    private func visibleLayouts(
        metrics: HomeFeatureCarouselMetrics
    ) -> [HomeFeatureCarouselCardLayout] {
        let displayedIndex = CGFloat(settledIndex) - (dragTranslation / metrics.travelDistance)
        let settledDisplayIndex = CGFloat(settledIndex)

        // 保留当前卡、相邻卡和下一层预备卡，避免边缘卡片在切换时突然出现或消失。
        return assetNames.indices
            .compactMap { assetIndex in
                let restingProjectedIndex = projectedIndex(
                    for: assetIndex,
                    displayedIndex: settledDisplayIndex
                )
                let restingPosition = restingProjectedIndex - settledDisplayIndex
                let position = restingPosition - (displayedIndex - settledDisplayIndex)

                guard shouldDisplayLayout(
                    restingPosition: restingPosition,
                    position: position
                ) else {
                    return nil
                }

                return HomeFeatureCarouselCardLayout(
                    assetIndex: assetIndex,
                    restingPosition: restingPosition,
                    position: position
                )
            }
            .sorted { left, right in
                let leftDistance = abs(left.position)
                let rightDistance = abs(right.position)

                if leftDistance == rightDistance {
                    return left.position < right.position
                }

                return leftDistance > rightDistance
            }
    }

    private func shouldDisplayLayout(
        restingPosition: CGFloat,
        position: CGFloat
    ) -> Bool {
        guard abs(position) <= 2.2 else {
            return false
        }

        if abs(restingPosition) <= 1.05 {
            return true
        }

        if dragTranslation < 0 {
            return restingPosition > 1.05
        }

        if dragTranslation > 0 {
            return restingPosition < -1.05
        }

        return false
    }

    private func carouselCard(
        assetName: String,
        layout: HomeFeatureCarouselCardLayout,
        metrics: HomeFeatureCarouselMetrics
    ) -> some View {
        let distance = min(abs(layout.position), 1)
        let cardSize = metrics.cardSize(for: distance)
        let grayscaleAmount = grayscaleAmount(for: layout.position)
        let opacityValue = opacity(for: layout.position)

        // 窗口尺寸负责层级变化，图片本体尺寸固定大于窗口，避免图片跟着卡片一起缩放。
        return HomeFeatureCarouselCardView(
            assetName: assetName,
            position: layout.position,
            cardSize: cardSize,
            grayscaleAmount: grayscaleAmount,
            metrics: metrics
        )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: metrics.cornerRadius,
                    style: .continuous
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: metrics.cornerRadius,
                    style: .continuous
                )
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
            )
            .shadow(
                color: Color.black.opacity(0.14),
                radius: 18,
                x: 0,
                y: 10
            )
            .offset(
                x: metrics.cardOffset(
                    restingPosition: layout.restingPosition,
                    dragTranslation: dragTranslation
                )
            )
            .opacity(Double(opacityValue))
            .zIndex(Double(2 - abs(layout.position)))
    }

    private func dragGesture(
        metrics: HomeFeatureCarouselMetrics
    ) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard assetNames.count > 1, shouldHandle(translation: value.translation) else {
                    return
                }

                isDraggingHorizontally = true
                dragTranslation = value.translation.width
            }
            .onEnded { value in
                guard isDraggingHorizontally else {
                    return
                }

                let progress = -value.translation.width / metrics.travelDistance
                let predictedProgress = -value.predictedEndTranslation.width / metrics.travelDistance
                let resolvedProgress = abs(predictedProgress) > abs(progress)
                    ? predictedProgress
                    : progress

                let step: Int
                if resolvedProgress > 0.35 {
                    step = 1
                } else if resolvedProgress < -0.35 {
                    step = -1
                } else {
                    step = 0
                }

                withAnimation(carouselAnimation) {
                    settledIndex += step
                    dragTranslation = 0
                }

                isDraggingHorizontally = false
                restartAutoAdvanceCycle()
            }
    }

    private func shouldHandle(translation: CGSize) -> Bool {
        abs(translation.width) > abs(translation.height)
    }

    private var selectedAssetIndex: Int {
        wrappedIndex(settledIndex)
    }

    @MainActor
    private func runAutoAdvanceCycle() async {
        guard assetNames.count > 1 else {
            return
        }

        do {
            try await Task.sleep(nanoseconds: autoAdvanceIntervalNanoseconds)
        } catch {
            return
        }

        guard !Task.isCancelled else {
            return
        }

        guard assetNames.count > 1, !isDraggingHorizontally else {
            restartAutoAdvanceCycle()
            return
        }

        withAnimation(carouselAnimation) {
            settledIndex += 1
        }

        restartAutoAdvanceCycle()
    }

    private func restartAutoAdvanceCycle() {
        autoAdvanceCycle &+= 1
    }

    private func wrappedIndex(_ index: Int, assetCount: Int? = nil) -> Int {
        let resolvedAssetCount = assetCount ?? assetNames.count

        guard resolvedAssetCount > 0 else {
            return 0
        }

        return ((index % resolvedAssetCount) + resolvedAssetCount) % resolvedAssetCount
    }

    private func projectedIndex(
        for assetIndex: Int,
        displayedIndex: CGFloat
    ) -> CGFloat {
        guard !assetNames.isEmpty else {
            return 0
        }

        let count = CGFloat(assetNames.count)
        let baseIndex = CGFloat(assetIndex)
        let cycleOffset = ((displayedIndex - baseIndex) / count).rounded()

        return baseIndex + (cycleOffset * count)
    }

    private func opacity(for position: CGFloat) -> CGFloat {
        let distance = abs(position)
        guard distance > 1 else {
            return 1
        }

        return 1 - smoothStep((distance - 1) / 1.1)
    }

    private func grayscaleAmount(for position: CGFloat) -> CGFloat {
        let distance = abs(position)
        guard distance > 0.5 else {
            return 0
        }

        return smoothStep((distance - 0.5) / 0.5)
    }

    private func smoothStep(_ value: CGFloat) -> CGFloat {
        let clampedValue = min(max(value, 0), 1)
        return clampedValue * clampedValue * (3 - (2 * clampedValue))
    }

    // 自动推进和手势吸附共用同一条动画曲线，方便统一调节首页轮播节奏。
    private var carouselAnimation: Animation {
        .easeInOut(duration: 0.85)
    }
}

/// 统一管理首页轮播的窗口尺寸、图片溢出和位移参数。
private struct HomeFeatureCarouselMetrics {
    let baseCardWidth: CGFloat
    let baseCardHeight: CGFloat
    let minimumCardScale: CGFloat
    let maximumCardScale: CGFloat
    let travelDistance: CGFloat
    let imageWidth: CGFloat
    let imageHeight: CGFloat
    let parallaxTravel: CGFloat
    let cornerRadius: CGFloat = 28

    init(containerWidth: CGFloat) {
        let resolvedCardWidth = min(max(containerWidth - 96, 214), 252)
        let resolvedCardHeight = resolvedCardWidth * 0.74
        let resolvedMinimumCardScale: CGFloat = 0.92
        let resolvedMaximumCardScale: CGFloat = 1.12
        let maximumCardWidth = resolvedCardWidth * resolvedMaximumCardScale
        let maximumCardHeight = resolvedCardHeight * resolvedMaximumCardScale

        // 图片固定比最大卡片更宽，视觉变化全部来自裁剪窗口扫过和反向位移。
        let imageOverflowWidth = min(max(maximumCardWidth * 0.80, 160), 210)

        baseCardWidth = resolvedCardWidth
        baseCardHeight = resolvedCardHeight
        minimumCardScale = resolvedMinimumCardScale
        maximumCardScale = resolvedMaximumCardScale
        imageWidth = maximumCardWidth + imageOverflowWidth
        imageHeight = maximumCardHeight
        parallaxTravel = imageOverflowWidth / 2
        travelDistance = (resolvedCardWidth / 2) + (maximumCardWidth / 2) + 14
    }

    func cardSize(for distance: CGFloat) -> CGSize {
        // 当前首页保留“主卡略小、两侧略大”的窗口层级；变化只作用在裁剪窗口。
        let scale = minimumCardScale + (
            (maximumCardScale - minimumCardScale) * smoothProgress(for: distance)
        )

        return CGSize(
            width: baseCardWidth * scale,
            height: baseCardHeight * scale
        )
    }

    func cardOffset(restingPosition: CGFloat, dragTranslation: CGFloat) -> CGFloat {
        let multiplier = dragResponseMultiplier(
            for: restingPosition,
            dragTranslation: dragTranslation
        )

        return (travelDistance * restingPosition) + (dragTranslation * multiplier)
    }

    func imageOffset(for position: CGFloat) -> CGFloat {
        let clampedPosition = min(max(position, -1), 1)

        // 图片相对卡片做反向缓动，让被裁出的内容变化比卡片位移更慢、更明显。
        return -clampedPosition * parallaxTravel
    }

    private func smoothProgress(for distance: CGFloat) -> CGFloat {
        let clampedDistance = min(max(distance, 0), 1)
        return clampedDistance * clampedDistance * (3 - (2 * clampedDistance))
    }

    private func dragResponseMultiplier(
        for restingPosition: CGFloat,
        dragTranslation: CGFloat
    ) -> CGFloat {
        guard dragTranslation != 0 else {
            return 0
        }

        guard restingPosition != 0 else {
            return 1
        }

        let isDraggingRight = dragTranslation > 0
        let isCardOnRight = restingPosition > 0
        let isOutgoingSide = isDraggingRight == isCardOnRight
        let distance = abs(restingPosition)

        if isOutgoingSide {
            return distance > 1.5 ? 1.3 : 1.16
        }

        return distance > 1.5 ? 0.44 : 0.78
    }
}

private struct HomeFeatureCarouselCardLayout: Identifiable {
    let assetIndex: Int
    let restingPosition: CGFloat
    let position: CGFloat

    var id: Int {
        assetIndex
    }
}

private struct HomeFeatureCarouselCardView: View {
    let assetName: String
    let position: CGFloat
    let cardSize: CGSize
    let grayscaleAmount: CGFloat
    let metrics: HomeFeatureCarouselMetrics

    var body: some View {
        // 先布局完整图片，再限制进当前卡片窗口，保证变化始终来自裁剪 + 位移。
        Image(assetName)
            .renderingMode(.original)
            .resizable()
            .scaledToFill()
            .frame(width: metrics.imageWidth, height: metrics.imageHeight)
            .grayscale(Double(grayscaleAmount))
            .offset(x: metrics.imageOffset(for: position))
            .frame(width: cardSize.width, height: cardSize.height)
            .clipped()
    }
}

struct HomeFeatureCarouselView_Previews: PreviewProvider {
    static var previews: some View {
        HomeFeatureCarouselView(
            assetNames: [
                "HomeCarouselGreenHills",
                "HomeCarouselGoldenValley",
                "HomeCarouselSnowMountains",
                "HomeCarouselCliffDawn",
            ]
        )
        .padding()
        .background(DUTheme.background)
        .previewLayout(.sizeThatFits)
    }
}
