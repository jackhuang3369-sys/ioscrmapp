import SwiftUI

struct HomeParallaxReelSectionView: View {
    let items: [HomeFeatureCarouselItem]
    let onSelectItem: (HomeFeatureCarouselItem) -> Void

    private let sectionHeight: CGFloat = 320
    private let cardHeight: CGFloat = 248
    private let cardSpacing: CGFloat = 12
    private let horizontalInset: CGFloat = 20
    private let itemVerticalPadding: CGFloat = 8
    private let titleSpacing: CGFloat = DUSpacing.md
    private let titleHorizontalInset: CGFloat = DUSpacing.lg

    private var itemHeight: CGFloat {
        sectionHeight - (itemVerticalPadding * 2)
    }

    var body: some View {
        reelContent
            .frame(height: sectionHeight)
    }

    @ViewBuilder
    private var reelContent: some View {
        if #available(iOS 17.0, *) {
            HomeParallaxReelIOS17ContentView(
                items: items,
                cardHeight: cardHeight,
                itemHeight: itemHeight,
                horizontalInset: horizontalInset,
                itemVerticalPadding: itemVerticalPadding,
                titleSpacing: titleSpacing,
                titleHorizontalInset: titleHorizontalInset,
                onSelectItem: onSelectItem
            )
        } else {
            GeometryReader { proxy in
                let cardWidth = max(min(proxy.size.width - 76, 328), 260)
                let sidePeekInset = max((proxy.size.width - cardWidth) / 2, horizontalInset)
                let viewportFrame = proxy.frame(in: .global)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: cardSpacing) {
                        ForEach(items) { item in
                            HomeParallaxReelLegacyCardView(
                                item: item,
                                cardSize: CGSize(width: cardWidth, height: cardHeight),
                                itemHeight: itemHeight,
                                titleSpacing: titleSpacing,
                                titleHorizontalInset: titleHorizontalInset,
                                viewportFrame: viewportFrame,
                                onTap: {
                                    onSelectItem(item)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, sidePeekInset)
                    .padding(.vertical, itemVerticalPadding)
                }
            }
        }
    }
}

@available(iOS 17.0, *)
private struct HomeParallaxReelIOS17ContentView: View {
    let items: [HomeFeatureCarouselItem]
    let cardHeight: CGFloat
    let itemHeight: CGFloat
    let horizontalInset: CGFloat
    let itemVerticalPadding: CGFloat
    let titleSpacing: CGFloat
    let titleHorizontalInset: CGFloat
    private let cardSpacing: CGFloat = 12
    let onSelectItem: (HomeFeatureCarouselItem) -> Void

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let cardWidth = max(size.width - 76, 260)
            let sidePeekInset = max((size.width - cardWidth) / 2, horizontalInset)

            ScrollView(.horizontal) {
                HStack(spacing: cardSpacing) {
                    ForEach(items) { item in
                        GeometryReader { proxy in
                            let cardSize = CGSize(width: proxy.size.width, height: cardHeight)
                            let itemFrame = proxy.frame(in: .scrollView)
                            let minX = min(itemFrame.minX * 0.8, proxy.size.width * 0.8)
                            let distanceRatio = homeParallaxReelDistanceRatio(
                                cardMidX: itemFrame.midX,
                                viewportWidth: size.width
                            )
                            let scaleX = 0.94 + (distanceRatio * 0.06)
                            let scaleY = 0.82 + (distanceRatio * 0.18)
                            let saturation = 1 - (distanceRatio * 0.62)
                            let grayscale = distanceRatio * 0.58

                            HomeParallaxReelCardUnitView(
                                item: item,
                                cardSize: cardSize,
                                imageWidth: cardSize.width * 1.24,
                                imageOffsetX: -minX,
                                titleWidth: max(cardSize.width - (titleHorizontalInset * 2), 0),
                                titleSpacing: titleSpacing,
                                showsBorder: false,
                                captionOpacity: 1,
                                shadowColor: Color.black.opacity(0.20 - (distanceRatio * 0.08)),
                                shadowRadius: 16
                            )
                            .frame(width: cardSize.width, height: proxy.size.height, alignment: .top)
                            .scaleEffect(x: scaleX, y: scaleY, anchor: .center)
                            .saturation(saturation)
                            .grayscale(grayscale)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onSelectItem(item)
                            }
                            .accessibilityAddTraits(.isButton)
                        }
                        .frame(width: cardWidth, height: itemHeight)
                    }
                }
                .padding(.horizontal, sidePeekInset)
                .padding(.vertical, itemVerticalPadding)
                .scrollTargetLayout()
                .frame(height: size.height, alignment: .top)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
        }
    }
}

private struct HomeParallaxReelLegacyCardView: View {
    let item: HomeFeatureCarouselItem
    let cardSize: CGSize
    let itemHeight: CGFloat
    let titleSpacing: CGFloat
    let titleHorizontalInset: CGFloat
    let viewportFrame: CGRect
    let onTap: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let itemFrame = proxy.frame(in: .global)
            let distanceRatio = normalizedDistanceRatio(itemFrame: itemFrame)
            let imageOffset = parallaxOffset(itemFrame: itemFrame)
            let scaleX = 0.94 + (distanceRatio * 0.06)
            let scaleY = 0.82 + (distanceRatio * 0.18)
            let saturation = 1 - (distanceRatio * 0.62)
            let grayscale = distanceRatio * 0.58

            HomeParallaxReelCardUnitView(
                item: item,
                cardSize: cardSize,
                imageWidth: cardSize.width * 1.42,
                imageOffsetX: imageOffset,
                titleWidth: max(cardSize.width - (titleHorizontalInset * 2), 0),
                titleSpacing: titleSpacing,
                showsBorder: true,
                captionOpacity: 1 - (distanceRatio * 0.24),
                shadowColor: Color.black.opacity(0.20 - (distanceRatio * 0.08)),
                shadowRadius: 16
            )
            .frame(width: cardSize.width, height: itemHeight, alignment: .top)
            .scaleEffect(x: scaleX, y: scaleY, anchor: .center)
            .saturation(saturation)
            .grayscale(grayscale)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .accessibilityAddTraits(.isButton)
        }
        .frame(width: cardSize.width, height: itemHeight)
    }

    private func normalizedDistanceRatio(itemFrame: CGRect) -> CGFloat {
        homeParallaxReelDistanceRatio(
            cardMidX: itemFrame.midX - viewportFrame.minX,
            viewportWidth: viewportFrame.width
        )
    }

    private func parallaxOffset(itemFrame: CGRect) -> CGFloat {
        let relativeOffset = itemFrame.minX - viewportFrame.minX
        return -(relativeOffset * 0.26)
    }
}

private struct HomeParallaxReelCardUnitView: View {
    let item: HomeFeatureCarouselItem
    let cardSize: CGSize
    let imageWidth: CGFloat
    let imageOffsetX: CGFloat
    let titleWidth: CGFloat
    let titleSpacing: CGFloat
    let showsBorder: Bool
    let captionOpacity: CGFloat
    let shadowColor: Color
    let shadowRadius: CGFloat

    var body: some View {
        VStack(spacing: titleSpacing) {
            HomeParallaxReelCardContentView(
                item: item,
                imageWidth: imageWidth,
                imageOffsetX: imageOffsetX,
                cardHeight: cardSize.height
            )
            .frame(width: cardSize.width, height: cardSize.height)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay {
                if showsBorder {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(.white.opacity(0.28), lineWidth: 1)
                }
            }
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                x: 0,
                y: 10
            )

            HomeParallaxReelCaptionView(item: item)
                .frame(width: titleWidth)
                .opacity(captionOpacity)
        }
        .frame(width: cardSize.width, alignment: .top)
    }
}

private struct HomeParallaxReelCaptionView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore

    let item: HomeFeatureCarouselItem

    var body: some View {
        Text(languageStore.string(item.title))
            .font(.du(15, weight: .semibold))
            .foregroundColor(DUTheme.ink)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .truncationMode(.tail)
    }
}

private struct HomeParallaxReelCardContentView: View {
    let item: HomeFeatureCarouselItem
    let imageWidth: CGFloat
    let imageOffsetX: CGFloat
    let cardHeight: CGFloat

    var body: some View {
        ZStack {
            Image(item.assetName)
                .renderingMode(.original)
                .resizable()
                .scaledToFill()
                .frame(width: imageWidth, height: cardHeight)
                .offset(x: imageOffsetX)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.14),
                    Color.black.opacity(0.64)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

private func homeParallaxReelDistanceRatio(
    cardMidX: CGFloat,
    viewportWidth: CGFloat
) -> CGFloat {
    let safeViewportWidth = max(viewportWidth, 1)
    let viewportMidX = safeViewportWidth / 2
    let distance = abs(cardMidX - viewportMidX)
    return min(distance / safeViewportWidth, 1)
}
