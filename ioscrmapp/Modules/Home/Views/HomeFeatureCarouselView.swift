import SwiftUI

/// 首页轮播图的模块内专用实现。
///
/// 实现路径为 `HomeView.featuredCarouselSection -> HomeFeatureCarouselView -> HomeFeatureCarouselCardView`。
/// 轮播轨道按“虚拟卡位”组织，切换时由整张卡片完成横向滑入 / 滑出。
/// 两侧预备卡会提前停在轨道边缘，避免切换时出现突兀的闪现或消失。
/// 两侧卡片继续保留灰度、透明度和尺寸差异，用来维持首页当前的层级感。
struct HomeFeatureCarouselView: View {
    let assetNames: [String]

    @State private var settledIndex = 0
    @State private var dragTranslation: CGFloat = 0
    @State private var isDraggingHorizontally = false
    @State private var autoAdvanceCycle = 0

    // 自动轮播切到下一张前的等待时间；4_000_000_000 = 4 秒。
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
        guard !assetNames.isEmpty else {
            return []
        }

        let displayedIndex = CGFloat(settledIndex) - (dragTranslation / metrics.travelDistance)
        let visibleSlotBuffer = 3

        // 通过虚拟卡位保留两侧预备卡，保证切换时始终有卡片沿轨道连续进出。
        return Array((settledIndex - visibleSlotBuffer)...(settledIndex + visibleSlotBuffer))
            .compactMap { virtualIndex in
                let position = CGFloat(virtualIndex) - displayedIndex

                guard abs(position) <= CGFloat(visibleSlotBuffer) + 0.1 else {
                    return nil
                }

                return HomeFeatureCarouselCardLayout(
                    virtualIndex: virtualIndex,
                    assetIndex: wrappedIndex(virtualIndex, assetCount: assetNames.count),
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

    private func carouselCard(
        assetName: String,
        layout: HomeFeatureCarouselCardLayout,
        metrics: HomeFeatureCarouselMetrics
    ) -> some View {
        let distance = min(abs(layout.position), 1)
        let cardSize = metrics.cardSize(for: distance)
        let grayscaleAmount = grayscaleAmount(for: layout.position)
        let opacityValue = opacity(for: layout.position)

        // 卡片整体沿轨道移动，图片保持居中承载，避免出现额外的漂移感。
        return HomeFeatureCarouselCardView(
            assetName: assetName,
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
                x: metrics.cardOffset(for: layout.position)
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

    private func opacity(for position: CGFloat) -> CGFloat {
        let distance = abs(position)
        let sideCardMinimumOpacity: CGFloat = 0.56

        if distance <= 0.18 {
            return 1
        }

        if distance <= 1 {
            let fadeProgress = smoothStep((distance - 0.18) / 0.82)
            return 1 - ((1 - sideCardMinimumOpacity) * fadeProgress)
        }

        let offscreenFadeProgress = smoothStep((distance - 1) / 0.7)
        return sideCardMinimumOpacity * (1 - offscreenFadeProgress)
    }

    private func grayscaleAmount(for position: CGFloat) -> CGFloat {
        let distance = abs(position)
        guard distance > 0.2 else {
            return 0
        }

        return smoothStep((distance - 0.2) / 0.55)
    }

    private func smoothStep(_ value: CGFloat) -> CGFloat {
        let clampedValue = min(max(value, 0), 1)
        return clampedValue * clampedValue * (3 - (2 * clampedValue))
    }

    // 切换动画时间从这里调整；改小更快，改大更慢。
    private var carouselAnimation: Animation {
        .easeInOut(duration: 0.82)
    }
}

/// 统一管理首页轮播的卡片尺寸、轨道间距和图片承载尺寸。
private struct HomeFeatureCarouselMetrics {
    let baseCardWidth: CGFloat
    let baseCardHeight: CGFloat
    let minimumCardScale: CGFloat
    let maximumCardScale: CGFloat
    let travelDistance: CGFloat
    let imageWidth: CGFloat
    let imageHeight: CGFloat
    let cornerRadius: CGFloat = 28

    init(containerWidth: CGFloat) {
        let resolvedCardWidth = min(max(containerWidth - 80, 224), 260)
        // 这里控制卡片视窗的高宽比，会直接影响图片上下被裁剪的程度。
        let resolvedCardHeight = resolvedCardWidth * 0.78
        // 这里控制主卡的窗口大小；值越大，主卡可见内容越多、裁剪越轻。
        let resolvedMinimumCardScale: CGFloat = 0.84
        // 这里控制两侧卡片的窗口大小；值越大，两侧卡片的裁剪越轻。
        let resolvedMaximumCardScale: CGFloat = 1.11
        // 主卡和两侧卡片的实际白缝压缩到原来的约 40%。
        let resolvedInterCardSpacing: CGFloat = 13
        let primaryCardWidth = resolvedCardWidth * resolvedMinimumCardScale
        let maximumCardWidth = resolvedCardWidth * resolvedMaximumCardScale
        let maximumCardHeight = resolvedCardHeight * resolvedMaximumCardScale

        baseCardWidth = resolvedCardWidth
        baseCardHeight = resolvedCardHeight
        minimumCardScale = resolvedMinimumCardScale
        maximumCardScale = resolvedMaximumCardScale
        // 图片承载尺寸越大，`scaledToFill` 之后被裁掉的内容越多；越接近卡片尺寸，裁剪越轻。
        imageWidth = maximumCardWidth
        imageHeight = maximumCardHeight
        travelDistance = (primaryCardWidth / 2) + (maximumCardWidth / 2) + resolvedInterCardSpacing
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

    func cardOffset(for position: CGFloat) -> CGFloat {
        travelDistance * position
    }

    private func smoothProgress(for distance: CGFloat) -> CGFloat {
        let clampedDistance = min(max(distance, 0), 1)
        return clampedDistance * clampedDistance * (3 - (2 * clampedDistance))
    }
}

private struct HomeFeatureCarouselCardLayout: Identifiable {
    let virtualIndex: Int
    let assetIndex: Int
    let position: CGFloat

    var id: Int {
        virtualIndex
    }
}

private struct HomeFeatureCarouselCardView: View {
    let assetName: String
    let cardSize: CGSize
    let grayscaleAmount: CGFloat
    let metrics: HomeFeatureCarouselMetrics

    var body: some View {
        // 图片保持居中承载，卡片本身负责切换时的滑动。
        // 如果要改“实际怎么裁剪”，优先看 `scaledToFill + frame + clipped` 这一组。
        Image(assetName)
            .renderingMode(.original)
            .resizable()
            .scaledToFill()
            .frame(width: metrics.imageWidth, height: metrics.imageHeight)
            .grayscale(Double(grayscaleAmount))
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
