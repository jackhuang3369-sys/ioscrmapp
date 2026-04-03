import SwiftUI

/// 首页轮播图的模块内专用实现。
///
/// 实现路径为 `HomeView.featuredCarouselSection -> HomeFeatureCarouselView -> HomeFeatureCarouselCardView`。
/// 轮播轨道按“虚拟卡位”组织，切换时由整张卡片完成横向滑入 / 滑出。
/// 两侧预备卡会提前停在轨道边缘，避免切换时出现突兀的闪现或消失。
/// 两侧卡片继续保留灰度、透明度和尺寸差异，用来维持首页当前的层级感。
struct HomeFeatureCarouselView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore

    let items: [HomeFeatureCarouselItem]
    let onSelectItem: (HomeFeatureCarouselItem) -> Void

    @State private var settledIndex = 0
    @State private var dragTranslation: CGFloat = 0
    @State private var isDraggingHorizontally = false
    @State private var autoAdvanceCycle = 0

    // 自动轮播切到下一张前的等待时间；4_000_000_000 = 4 秒。
    private let autoAdvanceIntervalNanoseconds: UInt64 = 4_000_000_000

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { proxy in
                let metrics = HomeFeatureCarouselMetrics(containerWidth: proxy.size.width)

                ZStack {
                    ForEach(visibleLayouts(metrics: metrics)) { layout in
                        carouselCard(
                            assetName: items[layout.assetIndex].assetName,
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
                .onTapGesture {
                    if let selectedItem {
                        onSelectItem(selectedItem)
                    }
                }
            }
            .frame(height: 226)

            if let selectedItem {
                Text(languageStore.string(selectedItem.title))
                    .font(.du(15, weight: .semibold))
                    .foregroundColor(DUTheme.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.top, 14)
                    .padding(.horizontal, 20)
            }

            if items.count > 1 {
                pageIndicator
                    .padding(.top, 10)
                    .padding(.bottom, 2)
            }
        }
        .task(id: autoAdvanceCycle) {
            await runAutoAdvanceCycle()
        }
        .onChange(of: items.count) { newCount in
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
        HStack(spacing: 8) {
            ForEach(items.indices, id: \.self) { index in
                pageIndicatorDot(isSelected: index == selectedAssetIndex)
            }
        }
    }

    @ViewBuilder
    private func pageIndicatorDot(isSelected: Bool) -> some View {
        if isSelected {
            Capsule()
                .fill(DUTheme.homeCarouselIndicatorGradient)
                .frame(width: 40, height: 8)
        } else {
            Capsule()
                .fill(DUTheme.homeCarouselIndicatorInactive)
                .frame(width: 8, height: 8)
        }
    }

    private func visibleLayouts(
        metrics: HomeFeatureCarouselMetrics
    ) -> [HomeFeatureCarouselCardLayout] {
        guard !items.isEmpty else {
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
                    assetIndex: wrappedIndex(virtualIndex, assetCount: items.count),
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
        let opacityValue = opacity(for: layout.position)
        let cardEffect = cardEffect(for: layout.position)
        let imageMotion = imageMotion(for: layout.position, cardSize: cardSize)

        // 卡片整体沿轨道移动；图片层再叠加“横向掠过 + 轻微透视”效果。
        return HomeFeatureCarouselCardView(
            assetName: assetName,
            cardSize: cardSize,
            imageMotion: imageMotion
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
                color: Color.black.opacity(cardEffect.shadowOpacity),
                radius: cardEffect.shadowRadius,
                x: 0,
                y: cardEffect.shadowYOffset
            )
            .scaleEffect(cardEffect.scale)
            .rotation3DEffect(
                .degrees(cardEffect.rotationDegrees),
                axis: (x: 0.14, y: 1, z: 0),
                anchor: layout.position < 0 ? .trailing : .leading,
                perspective: 0.82
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
                guard items.count > 1, shouldHandle(translation: value.translation) else {
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

    private var selectedItem: HomeFeatureCarouselItem? {
        guard !items.isEmpty else {
            return nil
        }

        return items[selectedAssetIndex]
    }

    @MainActor
    private func runAutoAdvanceCycle() async {
        guard items.count > 1 else {
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

        guard items.count > 1, !isDraggingHorizontally else {
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
        let resolvedAssetCount = assetCount ?? items.count

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

    private func cardEffect(for position: CGFloat) -> HomeFeatureCarouselCardEffect {
        let clampedPosition = min(max(position, -1), 1)
        let sweepProgress = lensSweepProgress(for: clampedPosition)

        return HomeFeatureCarouselCardEffect(
            scale: 1 + (0.038 * sweepProgress),
            rotationDegrees: Double(-clampedPosition) * Double(8 + (4 * sweepProgress)),
            shadowOpacity: 0.05 + (0.08 * sweepProgress),
            shadowRadius: 8 + (10 * sweepProgress),
            shadowYOffset: 2 + (8 * sweepProgress)
        )
    }

    private func imageMotion(
        for position: CGFloat,
        cardSize: CGSize
    ) -> HomeFeatureCarouselImageMotion {
        let clampedPosition = min(max(position, -1), 1)
        let distance = abs(clampedPosition)
        let sweepProgress = lensSweepProgress(for: clampedPosition)
        let horizontalOffset = -clampedPosition * cardSize.width * (2.0 / 3.0)
        let canvasWidth = cardSize.width + (abs(horizontalOffset) * 2)
        let canvasHeight = cardSize.height * (1.06 + (0.08 * distance))
        let imageScale = 1 + (0.12 * sweepProgress) + (0.05 * distance)

        return HomeFeatureCarouselImageMotion(
            canvasSize: CGSize(width: canvasWidth, height: canvasHeight),
            horizontalOffset: horizontalOffset,
            scale: imageScale
        )
    }

    private func lensSweepProgress(for position: CGFloat) -> CGFloat {
        let distance = min(max(abs(position), 0), 1)
        let centeredDistance = abs(distance - 0.5) / 0.5
        return 1 - smoothStep(centeredDistance)
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

private struct HomeFeatureCarouselCardEffect {
    let scale: CGFloat
    let rotationDegrees: Double
    let shadowOpacity: CGFloat
    let shadowRadius: CGFloat
    let shadowYOffset: CGFloat
}

private struct HomeFeatureCarouselImageMotion {
    let canvasSize: CGSize
    let horizontalOffset: CGFloat
    let scale: CGFloat
}

private struct HomeFeatureCarouselCardView: View {
    let assetName: String
    let cardSize: CGSize
    let imageMotion: HomeFeatureCarouselImageMotion

    var body: some View {
        // 图片内容跟随卡位方向一起平移，形成“镜头掠过”的跟手感。
        Image(assetName)
            .renderingMode(.original)
            .resizable()
            .scaledToFill()
            .frame(
                width: imageMotion.canvasSize.width,
                height: imageMotion.canvasSize.height
            )
            .scaleEffect(imageMotion.scale)
            .offset(x: imageMotion.horizontalOffset)
            .frame(width: cardSize.width, height: cardSize.height)
            .clipped()
    }
}

struct HomeFeatureCarouselView_Previews: PreviewProvider {
    static var previews: some View {
        HomeFeatureCarouselView(
            items: [
                .init(
                    assetName: "HomeCarouselWeather3D",
                    title: .literal("One DU ecosystem for every screen")
                ),
                .init(
                    assetName: "HomeCarouselTelecomEco",
                    title: .literal("3D weather, your day at a glance"),
                    action: .tickets
                ),
                .init(
                    assetName: "HomeCarouselIPhone17",
                    title: .literal("iPhone 17 Slim, lighter than ever"),
                    action: .mall
                ),
                .init(
                    assetName: "HomeCarouselSpiderMovie",
                    title: .literal("SPIDER-MAN: BRAND NEW DAY"),
                    action: .videoDetail("spiderman_2026")
                ),
            ]
        ) { _ in }
        .padding()
        .background(DUTheme.background)
        .previewLayout(.sizeThatFits)
        .environmentObject(AppLanguageStore(initialLanguage: .english))
    }
}
