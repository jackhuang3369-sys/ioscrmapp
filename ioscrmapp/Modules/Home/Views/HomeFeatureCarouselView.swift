import SwiftUI

struct HomeFeatureCarouselView: View {
    let assetNames: [String]

    @State private var selectedIndex = 0
    @State private var dragTranslation: CGFloat = 0
    @State private var isDraggingHorizontally = false

    private let autoAdvanceTimer = Timer.publish(
        every: 4,
        on: .main,
        in: .common
    ).autoconnect()

    var body: some View {
        VStack(spacing: DUSpacing.md) {
            GeometryReader { proxy in
                let metrics = HomeFeatureCarouselMetrics(containerWidth: proxy.size.width)

                ZStack {
                    ForEach(visibleLayouts(metrics: metrics)) { layout in
                        carouselCard(
                            assetName: assetNames[layout.index],
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
        .onReceive(autoAdvanceTimer) { _ in
            guard assetNames.count > 1, !isDraggingHorizontally else {
                return
            }

            withAnimation(carouselAnimation) {
                selectedIndex = wrappedIndex(selectedIndex + 1)
            }
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: DUSpacing.xs) {
            ForEach(assetNames.indices, id: \.self) { index in
                Capsule()
                    .fill(
                        index == selectedIndex
                        ? DUTheme.cyan
                        : DUTheme.inkDisabled.opacity(0.35)
                    )
                    .frame(width: index == selectedIndex ? 18 : 6, height: 6)
            }
        }
    }

    private func visibleLayouts(
        metrics: HomeFeatureCarouselMetrics
    ) -> [HomeFeatureCarouselCardLayout] {
        let displayedIndex = CGFloat(selectedIndex) - (dragTranslation / metrics.travelDistance)

        return assetNames.indices
            .compactMap { index in
                let position = wrappedRelativePosition(
                    for: index,
                    displayedIndex: displayedIndex
                )

                guard abs(position) <= 1.45 else {
                    return nil
                }

                return HomeFeatureCarouselCardLayout(
                    index: index,
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
        let size = metrics.cardSize(for: distance)
        let grayscaleAmount = grayscaleAmount(for: layout.position)
        let opacityValue = opacity(for: layout.position)

        return Image(assetName)
            .renderingMode(.original)
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)
            .grayscale(Double(grayscaleAmount))
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
            .offset(x: metrics.travelDistance * layout.position)
            .opacity(Double(opacityValue))
            .zIndex(Double(2 - abs(layout.position)))
    }

    private func dragGesture(
        metrics: HomeFeatureCarouselMetrics
    ) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard shouldHandle(translation: value.translation) else {
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
                    selectedIndex = wrappedIndex(selectedIndex + step)
                    dragTranslation = 0
                }

                isDraggingHorizontally = false
            }
    }

    private func shouldHandle(translation: CGSize) -> Bool {
        abs(translation.width) > abs(translation.height)
    }

    private func wrappedIndex(_ index: Int) -> Int {
        guard !assetNames.isEmpty else {
            return 0
        }

        let count = assetNames.count
        return ((index % count) + count) % count
    }

    private func wrappedRelativePosition(
        for index: Int,
        displayedIndex: CGFloat
    ) -> CGFloat {
        guard !assetNames.isEmpty else {
            return 0
        }

        let count = CGFloat(assetNames.count)
        var distance = CGFloat(index) - displayedIndex

        if distance > count / 2 {
            distance -= count
        } else if distance < -count / 2 {
            distance += count
        }

        return distance
    }

    private func grayscaleAmount(for position: CGFloat) -> CGFloat {
        let distance = abs(position)
        guard distance > 0.5 else {
            return 0
        }

        return smoothStep((distance - 0.5) / 0.5)
    }

    private func opacity(for position: CGFloat) -> CGFloat {
        let distance = abs(position)
        guard distance > 1 else {
            return 1
        }

        return 1 - smoothStep((distance - 1) / 0.45)
    }

    private func smoothStep(_ value: CGFloat) -> CGFloat {
        let clampedValue = min(max(value, 0), 1)
        return clampedValue * clampedValue * (3 - (2 * clampedValue))
    }

    private var carouselAnimation: Animation {
        .easeInOut(duration: 0.42)
    }
}

private struct HomeFeatureCarouselMetrics {
    let containerWidth: CGFloat
    let centerCardWidth: CGFloat
    let centerCardHeight: CGFloat
    let sideScale: CGFloat
    let travelDistance: CGFloat
    let cornerRadius: CGFloat = 28

    init(containerWidth: CGFloat) {
        self.containerWidth = containerWidth

        let resolvedCenterWidth = min(max(containerWidth - 96, 214), 252)
        centerCardWidth = resolvedCenterWidth
        centerCardHeight = resolvedCenterWidth * 0.74
        sideScale = 1.12
        travelDistance = (resolvedCenterWidth / 2) + ((resolvedCenterWidth * sideScale) / 2) + 14
    }

    func cardSize(for distance: CGFloat) -> CGSize {
        let scale = 0.92 + (0.20 * smoothScaleProgress(for: distance))
        return CGSize(
            width: centerCardWidth * scale,
            height: centerCardHeight * scale
        )
    }

    private func smoothScaleProgress(for distance: CGFloat) -> CGFloat {
        let clampedDistance = min(max(distance, 0), 1)
        return clampedDistance * clampedDistance * (3 - (2 * clampedDistance))
    }
}

private struct HomeFeatureCarouselCardLayout: Identifiable {
    let index: Int
    let position: CGFloat

    var id: Int {
        index
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
