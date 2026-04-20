import SwiftUI
import WebKit

private let mallProductDetailScrollCoordinateSpaceName = "MallProductDetailScroll"
private let mallProductDetailBottomTabBarKey = "mall-product-detail"

struct MallProductDetailView: View {
    @Environment(\.duTheme) private var theme
    @EnvironmentObject private var languageStore: AppLanguageStore
    @EnvironmentObject private var homeChromeState: HomeChromeState
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: MallViewModel
    let product: MallProduct

    @State private var screenState: ScreenState = .loading
    @State private var snapshot: MallProductDetailSnapshot?
    @State private var selectedValueIDs: Set<String> = []
    @State private var draftValueIDs: Set<String> = []
    @State private var selectedHeroIndex = 0
    @State private var isSearchPresented = false
    @State private var isCartPresented = false
    @State private var isSelectionSheetPresented = false
    @State private var activeImagePreview: MallImagePreviewContext?
    @State private var productSectionMinY: CGFloat = .greatestFiniteMagnitude
    @State private var detailSectionMinY: CGFloat = .greatestFiniteMagnitude
    @State private var activeSection: MallProductDetailSection = .product
    @State private var pendingSelectionAction: SelectionAction = .selectOnly
    @State private var activeAlert: MallProductDetailNotice?

    private let productSectionAnchorID = "mall-product-detail-product-section"
    private let detailSectionAnchorID = "mall-product-detail-detail-section"

    var body: some View {
        ZStack {
            MallPalette(theme: theme).canvasBackground
                .ignoresSafeArea()

            content
        }
        .navigationBarHidden(true)
        .overlay(navigationLinks)
        .duBottomSheet(
            isPresented: $isSelectionSheetPresented,
            preferredHeight: 610,
            showsGrabber: false
        ) {
            if let snapshot {
                MallProductSelectionSheet(
                    snapshot: snapshot,
                    selectedValueIDs: $draftValueIDs,
                    locale: languageStore.locale,
                    language: languageStore.currentLanguage,
                    onPreviewImage: { image in
                        presentImagePreview(images: [image])
                    },
                    onClose: {
                        isSelectionSheetPresented = false
                    },
                    onConfirm: confirmSelectedProduct
                )
                .environmentObject(languageStore)
            }
        }
        .fullScreenCover(item: $activeImagePreview) { preview in
            MallImagePreviewScreen(
                images: preview.images,
                initialIndex: preview.initialIndex
            )
        }
        .task(id: product.id) {
            await loadSnapshot()
        }
        .onAppear {
            homeChromeState.hideBottomTabBar(for: mallProductDetailBottomTabBarKey)
        }
        .onDisappear {
            homeChromeState.showBottomTabBar(for: mallProductDetailBottomTabBarKey)
        }
        .alert(item: $activeAlert) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text(languageStore.string("common.ok")))
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        switch screenState {
        case .loading:
            MallProductDetailLoadingView()
        case .failed:
            MallProductDetailFailureView {
                Task {
                    await loadSnapshot()
                }
            }
        case .loaded:
            if let snapshot, let currentSKU = snapshot.currentSKU(for: selectedValueIDs) {
                loadedContent(snapshot: snapshot, currentSKU: currentSKU)
            } else {
                EmptyView()
            }
        }
    }

    private func loadedContent(
        snapshot: MallProductDetailSnapshot,
        currentSKU: MallProductDetailSKU
    ) -> some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top
            let bottomInset = proxy.safeAreaInsets.bottom
            let bottomActionBarMetrics = MallBottomActionBarLayout.metrics(
                buttonHeight: MallProductDetailLayout.bottomActionBarButtonHeight,
                bottomSafeInset: bottomInset
            )
            // 详情段落滚到这个阈值后，吸顶 Tab 高亮从“宝贝”切到“详情”。
            let detailsActivationThreshold = MallProductDetailLayout.detailsActivationThreshold(topInset: topInset)
            // 商品信息区顶到这里后，首屏浮层切换成吸顶头部。
            let showsCollapsedChrome = productSectionMinY <= MallProductDetailLayout.collapsedChromeTriggerY(topInset: topInset)
            // 给滚动内容预留底部固定购买栏高度，避免正文被底栏压住。
            let bottomActionBarHeight = bottomActionBarMetrics.reservedHeight
            let cartBadgeCount = viewModel.cartBadgeCount

            ScrollViewReader { scrollProxy in
                ZStack(alignment: .top) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            MallProductHeroStage(
                                snapshot: snapshot,
                                currentSKU: currentSKU,
                                selectedHeroIndex: $selectedHeroIndex,
                                selectedValueIDs: selectedValueIDs,
                                language: languageStore.currentLanguage,
                                topInset: topInset,
                                onSelectPrimaryValue: { group, valueID in
                                    applySelection(
                                        valueID: valueID,
                                        in: group,
                                        to: &selectedValueIDs
                                    )
                                },
                                onPreviewImage: {
                                    presentImagePreview(images: [currentSKU.previewImage])
                                }
                            )

                            Color.clear
                                .frame(height: 1)
                                .id(productSectionAnchorID)
                                .background(
                                    MallProductDetailScrollMetricReader(
                                        coordinateSpaceName: mallProductDetailScrollCoordinateSpaceName
                                    ) { value in
                                        productSectionMinY = value
                                        activeSection = resolvedActiveSection(
                                            detailSectionMinY: detailSectionMinY,
                                            threshold: detailsActivationThreshold
                                        )
                                    }
                                )

                            // 价格区与信息卡片之间只保留紧凑分隔，避免首屏信息被竖向空白拉散。
                            VStack(alignment: .leading, spacing: 3) {
                                MallProductSummaryCard(
                                    saleLabel: snapshot.saleLabel.value(for: languageStore.currentLanguage),
                                    priceText: currentSKU.formattedPrice(for: languageStore.locale),
                                    countdownLabel: languageStore.string("mall.detail.saleEnds.label"),
                                    saleEndsText: currentSKU.saleEndsText.value(for: languageStore.currentLanguage),
                                    title: snapshot.title.value(for: languageStore.currentLanguage),
                                    subtitle: snapshot.subtitle.value(for: languageStore.currentLanguage)
                                )

                                MallProductInfoPanel(
                                    selectedLabel: languageStore.string("mall.detail.selected.label"),
                                    selectedValue: snapshot.selectedSummary(
                                        for: currentSKU,
                                        language: languageStore.currentLanguage
                                    ),
                                    shipmentLabel: languageStore.string("mall.detail.shipment.label"),
                                    shipmentValue: snapshot.shipmentSummary.value(for: languageStore.currentLanguage),
                                    deliveredToLabel: languageStore.string("mall.detail.deliveredTo.label"),
                                    deliveredToValue: snapshot.deliveryAddressSummary.value(for: languageStore.currentLanguage),
                                    onSelected: {
                                        openSelectionSheet()
                                    },
                                    onShipment: {},
                                    onDeliveredTo: {}
                                )

                                Color.clear
                                    .frame(height: 1)
                                    .id(detailSectionAnchorID)
                                    .background(
                                        MallProductDetailScrollMetricReader(
                                            coordinateSpaceName: mallProductDetailScrollCoordinateSpaceName
                                        ) { value in
                                            detailSectionMinY = value
                                            activeSection = resolvedActiveSection(
                                                detailSectionMinY: value,
                                                threshold: detailsActivationThreshold
                                            )
                                        }
                                    )

                                MallProductHTMLSection(
                                    title: snapshot.detailSectionTitle.value(for: languageStore.currentLanguage),
                                    html: snapshot.detailHTML.value(for: languageStore.currentLanguage),
                                    language: languageStore.currentLanguage,
                                    onOpenImageURL: openDetailImagePreview
                                )
                            }
                            .padding(.bottom, bottomActionBarHeight + DUSpacing.xl)
                        }
                    }
                    .coordinateSpace(name: mallProductDetailScrollCoordinateSpaceName)
                    .ignoresSafeArea(edges: .top)

                    if showsCollapsedChrome {
                        MallProductDetailCollapsedChrome(
                            topInset: topInset,
                            searchPlaceholder: snapshot.searchPlaceholder.value(for: languageStore.currentLanguage),
                            cartBadgeCount: cartBadgeCount,
                            activeSection: activeSection,
                            language: languageStore.currentLanguage,
                            onBack: { dismiss() },
                            onSearch: { isSearchPresented = true },
                            onCart: { isCartPresented = true },
                            onSelectSection: { section in
                                activeSection = section
                                withAnimation(.easeInOut(duration: 0.24)) {
                                    switch section {
                                    case .product:
                                        scrollProxy.scrollTo(productSectionAnchorID, anchor: .top)
                                    case .details:
                                        scrollProxy.scrollTo(detailSectionAnchorID, anchor: .top)
                                    }
                                }
                            }
                        )
                        .ignoresSafeArea(edges: .top)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(2)
                    } else {
                        MallProductDetailFloatingChrome(
                            topInset: topInset,
                            cartBadgeCount: cartBadgeCount,
                            onBack: { dismiss() },
                            onCart: { isCartPresented = true }
                        )
                        .ignoresSafeArea(edges: .top)
                        .zIndex(1)
                    }
                }
                .overlay(alignment: .bottom) {
                    MallProductBottomActionBar(
                        cartBadgeCount: cartBadgeCount,
                        homeTitle: languageStore.string("mall.detail.home"),
                        cartTitle: languageStore.string("mall.detail.shoppingCart"),
                        addToCartTitle: languageStore.string("mall.detail.addToCart"),
                        buyNowTitle: languageStore.string("mall.detail.buyNow"),
                        buyNowPriceText: currentSKU.formattedPrice(for: languageStore.locale),
                        bottomSafeInset: bottomInset,
                        onHome: { dismiss() },
                        onCart: { isCartPresented = true },
                        onAddToCart: {
                            openSelectionSheet(for: .addToCart)
                        },
                        onBuyNow: {
                            openSelectionSheet(for: .buyNow)
                        }
                    )
                    .ignoresSafeArea(edges: .bottom)
                    .zIndex(3)
                }
            }
        }
    }

    private var navigationLinks: some View {
        Group {
            NavigationLink(
                destination: MallSearchView(viewModel: viewModel),
                isActive: $isSearchPresented
            ) {
                EmptyView()
            }
            .hidden()

            NavigationLink(
                destination: MallCartView(viewModel: viewModel),
                isActive: $isCartPresented
            ) {
                EmptyView()
            }
            .hidden()
        }
    }

    private func openSelectionSheet(for action: SelectionAction = .selectOnly) {
        pendingSelectionAction = action
        draftValueIDs = selectedValueIDs
        isSelectionSheetPresented = true
    }

    private func presentImagePreview(
        images: [MallImageSource],
        initialIndex: Int = 0
    ) {
        guard !images.isEmpty else {
            return
        }

        activeImagePreview = MallImagePreviewContext(
            images: images,
            initialIndex: initialIndex
        )
    }

    private func openDetailImagePreview(_ imageURLString: String) {
        guard let imageURL = URL(string: imageURLString) else {
            return
        }

        presentImagePreview(images: [.remote(url: imageURL)])
    }

    private func confirmSelectedProduct() {
        guard
            let snapshot,
            let matchedSKU = snapshot.currentSKU(for: draftValueIDs)
        else {
            return
        }

        selectedValueIDs = Set(matchedSKU.valueIDs)
        isSelectionSheetPresented = false

        switch pendingSelectionAction {
        case .selectOnly:
            break
        case .addToCart:
            Task { @MainActor in
                do {
                    try await viewModel.addCartItem(
                        product: product,
                        detailSnapshot: snapshot,
                        sku: matchedSKU
                    )
                } catch {
                    presentCartError(error)
                }
            }
        case .buyNow:
            activeAlert = MallProductDetailNotice(
                title: languageStore.string("mall.cart.checkout.title"),
                message: languageStore.string("mall.cart.checkout.placeholder")
            )
        }

        pendingSelectionAction = .selectOnly
    }

    private func loadSnapshot() async {
        screenState = .loading
        snapshot = nil
        selectedValueIDs = []
        draftValueIDs = []
        selectedHeroIndex = 0
        productSectionMinY = .greatestFiniteMagnitude
        detailSectionMinY = .greatestFiniteMagnitude
        activeSection = .product

        try? await Task.sleep(nanoseconds: 120_000_000)

        do {
            let entry = try await viewModel.fetchProductDetailEntry(productID: product.id)
            guard let defaultSKU = entry.snapshot.defaultSKU else {
                screenState = .failed
                return
            }

            snapshot = entry.snapshot
            selectedValueIDs = Set(defaultSKU.valueIDs)
            draftValueIDs = Set(defaultSKU.valueIDs)
            screenState = .loaded
        } catch {
            screenState = .failed
        }
    }

    private func applySelection(
        valueID: String,
        in group: MallProductDetailSpecificationGroup,
        to valueIDs: inout Set<String>
    ) {
        guard let snapshot else {
            return
        }

        let groupValueIDs = Set(group.values.map(\.id))
        var nextValueIDs = valueIDs.subtracting(groupValueIDs)
        nextValueIDs.insert(valueID)

        if let matchedSKU = snapshot.currentSKU(for: nextValueIDs) {
            valueIDs = Set(matchedSKU.valueIDs)
        } else {
            valueIDs = nextValueIDs
        }
    }

    private func resolvedActiveSection(
        detailSectionMinY: CGFloat,
        threshold: CGFloat
    ) -> MallProductDetailSection {
        detailSectionMinY <= threshold ? .details : .product
    }

    private func presentCartError(_ error: Error) {
        let message: String

        if let serviceError = error as? MallServiceError {
            message = languageStore.string(serviceError.textValue)
        } else {
            message = languageStore.string("mall.cart.error.subtitle")
        }

        activeAlert = MallProductDetailNotice(
            title: languageStore.string("mall.cart.error.title"),
            message: message
        )
    }
}

private extension MallProductDetailView {
    enum ScreenState {
        case loading
        case loaded
        case failed
    }

    enum SelectionAction {
        case selectOnly
        case addToCart
        case buyNow
    }
}

private struct MallProductDetailNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private enum MallProductDetailLayout {
    // 吸顶搜索头和下方 Tab 之间的底部留白。
    static let collapsedChromeBottomPadding: CGFloat = 8
    // 吸顶 Tab 的可视高度。
    static let stickyTabsHeight: CGFloat = 50
    // 底部购买按钮的主高度。
    static let bottomActionBarButtonHeight: CGFloat = 36
    // 顶部返回/购物车两种状态共用同一套尺寸，后续只改这里。
    static let chromeButtonSize: CGFloat = 30.6
    static let chromeButtonIconSize: CGFloat = 14.4

    static func collapsedChromeHeight(topInset: CGFloat) -> CGFloat {
        chromeToolbarTopOffset(topInset: topInset)
            + chromeButtonSize
            + collapsedChromeBottomPadding
            + stickyTabsHeight
    }

    static func collapsedChromeTriggerY(topInset: CGFloat) -> CGFloat {
        chromeToolbarTopOffset(topInset: topInset) + 28
    }

    static func detailsActivationThreshold(topInset: CGFloat) -> CGFloat {
        collapsedChromeHeight(topInset: topInset) + 12
    }

    static func chromeToolbarTopOffset(topInset: CGFloat) -> CGFloat {
        // 允许顶部按钮越过安全区，但再往下放一点，避免过贴顶部边框。
        max(30, topInset * 0.84 - 2)
    }
}

private enum MallProductDetailSection: Equatable {
    case product
    case details
}

private struct MallProductDetailScrollMetricReader: View {
    let coordinateSpaceName: String
    let onChange: (CGFloat) -> Void

    var body: some View {
        GeometryReader { proxy in
            let minY = proxy.frame(in: .named(coordinateSpaceName)).minY

            Color.clear
                .frame(height: 1)
                .task(id: minY) {
                    onChange(minY)
                }
        }
        .frame(height: 1)
        .allowsHitTesting(false)
    }
}

private struct MallProductDetailFloatingChrome: View {
    let topInset: CGFloat
    let cartBadgeCount: Int
    let onBack: () -> Void
    let onCart: () -> Void

    var body: some View {
        HStack {
            MallProductDetailChromeIconButton(
                systemName: "chevron.left",
                action: onBack
            )
            Spacer(minLength: 0)
            MallProductDetailChromeBadgeButton(
                systemName: "cart",
                badgeCount: cartBadgeCount,
                action: onCart
            )
        }
        .padding(.horizontal, DUSpacing.md)
        .padding(.top, MallProductDetailLayout.chromeToolbarTopOffset(topInset: topInset))
    }
}

private struct MallProductDetailCollapsedChrome: View {
    @Environment(\.duTheme) private var theme

    let topInset: CGFloat
    let searchPlaceholder: String
    let cartBadgeCount: Int
    let activeSection: MallProductDetailSection
    let language: AppLanguage
    let onBack: () -> Void
    let onSearch: () -> Void
    let onCart: () -> Void
    let onSelectSection: (MallProductDetailSection) -> Void

    var body: some View {
        let palette = MallPalette(theme: theme)

        VStack(spacing: 0) {
            HStack(spacing: DUSpacing.md) {
                MallProductDetailChromeIconButton(
                    systemName: "chevron.left",
                    action: onBack
                )

                Button(action: onSearch) {
                    HStack(spacing: DUSpacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .font(.du(.labelStrong))
                            .foregroundColor(palette.inverseText.opacity(0.94))

                        Text(searchPlaceholder)
                            .font(.du(.metaStrong))
                            .foregroundColor(palette.inverseText.opacity(0.84))
                            .lineLimit(1)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, DUSpacing.md)
                    .frame(height: 36)
                    .background(DUColorPrimitives.Neutral.black.opacity(0.16))
                    .overlay(
                        RoundedRectangle(cornerRadius: DURadius.sm + 2, style: .continuous)
                            .stroke(palette.inverseText.opacity(0.18), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: DURadius.sm + 2, style: .continuous))
                }
                .buttonStyle(.plain)

                MallProductDetailChromeBadgeButton(
                    systemName: "cart",
                    badgeCount: cartBadgeCount,
                    action: onCart
                )
            }
            .padding(.horizontal, DUSpacing.md)
            .padding(.top, MallProductDetailLayout.chromeToolbarTopOffset(topInset: topInset))
            .padding(.bottom, MallProductDetailLayout.collapsedChromeBottomPadding)
            .background(
                theme.colors.gradient.brand
                    .overlay(DUColorPrimitives.Neutral.black.opacity(0.04))
                    .ignoresSafeArea(edges: .top)
            )

            MallProductDetailStickyTabs(
                activeSection: activeSection,
                language: language,
                onSelectSection: onSelectSection
            )
        }
        .shadow(color: DUElevation.control.color, radius: DUElevation.control.radius, x: DUElevation.control.x, y: 4)
    }
}

private struct MallProductDetailChromeBadgeButton: View {
    @Environment(\.duTheme) private var theme

    let systemName: String
    let badgeCount: Int
    let action: () -> Void

    var body: some View {
        let palette = MallPalette(theme: theme)

        ZStack(alignment: .topTrailing) {
            MallProductDetailChromeIconButton(
                systemName: systemName,
                action: action
            )

            if badgeCount > 0 {
                Text("\(badgeCount)")
                    .font(.du(.microStrong))
                    .foregroundColor(palette.inverseText)
                    .padding(.horizontal, DUSpacing.xs)
                    .frame(height: 16)
                    .background(palette.badgeGradient(for: .sale))
                    .clipShape(Capsule())
                    .offset(x: 4, y: -3)
            }
        }
    }
}

private struct MallProductDetailChromeIconButton: View {
    @Environment(\.duTheme) private var theme

    let systemName: String
    let action: () -> Void

    var body: some View {
        let palette = MallPalette(theme: theme)

        Button(action: action) {
            Image(systemName: systemName)
                .font(.du(.bodyEmphasized))
                .foregroundColor(palette.inverseText)
                .frame(
                    width: MallProductDetailLayout.chromeButtonSize,
                    height: MallProductDetailLayout.chromeButtonSize
                )
                .background(
                    RoundedRectangle(cornerRadius: DURadius.sm + 2, style: .continuous)
                        .fill(DUColorPrimitives.Neutral.black.opacity(0.16))
                        .overlay(
                            RoundedRectangle(cornerRadius: DURadius.sm + 2, style: .continuous)
                                .stroke(palette.inverseText.opacity(0.18), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

private struct MallProductDetailStickyTabs: View {
    @Environment(\.duTheme) private var theme

    let activeSection: MallProductDetailSection
    let language: AppLanguage
    let onSelectSection: (MallProductDetailSection) -> Void

    var body: some View {
        let palette = MallPalette(theme: theme)

        HStack(spacing: 0) {
            tabButton(for: .product)
            tabButton(for: .details)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DUSpacing.xxl)
        .background(palette.panelBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(palette.subtleBorder)
                .frame(height: 1)
        }
    }

    private func tabButton(for section: MallProductDetailSection) -> some View {
        let isActive = activeSection == section

        return Button {
            onSelectSection(section)
        } label: {
            VStack(spacing: 10) {
                Text(title(for: section))
                    .font(.du(isActive ? .bodyLargeStrong : .bodyLargeSemibold))
                    .foregroundColor(isActive ? MallPalette(theme: theme).primaryText : MallPalette(theme: theme).disabledText)

                Capsule()
                    .fill(isActive ? MallPalette(theme: theme).primaryText : Color.clear)
                    .frame(width: 34, height: 3)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        }
        .buttonStyle(.plain)
    }

    private func title(for section: MallProductDetailSection) -> String {
        switch (language, section) {
        case (.simplifiedChinese, .product):
            return "宝贝"
        case (.simplifiedChinese, .details):
            return "详情"
        case (.english, .product):
            return "Product"
        case (.english, .details):
            return "Details"
        case (.arabic, .product):
            return "المنتج"
        case (.arabic, .details):
            return "التفاصيل"
        }
    }
}

private struct MallProductHeroStage: View {
    @Environment(\.duTheme) private var theme

    let snapshot: MallProductDetailSnapshot
    let currentSKU: MallProductDetailSKU
    @Binding var selectedHeroIndex: Int
    let selectedValueIDs: Set<String>
    let language: AppLanguage
    let topInset: CGFloat
    let onSelectPrimaryValue: (MallProductDetailSpecificationGroup, String) -> Void
    let onPreviewImage: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedHeroIndex) {
                ForEach(Array(snapshot.heroMedia.enumerated()), id: \.offset) { index, media in
                    MallProductHeroPage(
                        media: media,
                        displayImage: currentSKU.previewImage
                    )
                    .tag(index)
                }
            }
            .frame(height: Self.heroHeight(topInset: topInset))
            .tabViewStyle(.page(indexDisplayMode: .never))
            .background(MallPalette(theme: theme).panelBackground)
            .contentShape(Rectangle())
            .onTapGesture(perform: onPreviewImage)

            if let featuredGroup {
                MallProductPrimaryThumbnailStrip(
                    group: featuredGroup,
                    selectedValueID: selectedValueID,
                    availableValueIDs: featuredAvailableValueIDs,
                    typesSummary: snapshot.typesSummary(language: language),
                    onSelectValue: { valueID in
                        onSelectPrimaryValue(featuredGroup, valueID)
                    }
                )
                .padding(.horizontal, DUSpacing.sm)
                .padding(.vertical, DUSpacing.sm)
                .background(MallPalette(theme: theme).panelBackground)
            }
        }
    }

    private var featuredGroup: MallProductDetailSpecificationGroup? {
        snapshot.specificationGroups.first { group in
            group.displayMode == .imageTile && group.values.contains { $0.image != nil }
        }
    }

    private var selectedValueID: String? {
        guard let featuredGroup else {
            return nil
        }

        return snapshot.selectedValueID(for: featuredGroup.id, in: currentSKU)
    }

    private var featuredAvailableValueIDs: Set<String> {
        guard let featuredGroup else {
            return []
        }

        return snapshot.availableValueIDs(
            for: featuredGroup.id,
            selectedValueIDs: selectedValueIDs
        )
    }

    static func heroHeight(topInset: CGFloat) -> CGFloat {
        topInset + 356
    }
}

private struct MallProductHeroPage: View {
    @Environment(\.duTheme) private var theme

    let media: MallProductDetailHeroMedia
    let displayImage: MallImageSource

    var body: some View {
        ZStack {
            MallImageView(
                image: displayImage,
                cornerRadius: 0,
                cropsBitmapToFill: true,
                bitmapFillScale: 1.05
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            MallPalette(theme: theme).heroMediaOverlay

            if media.type == .video {
                Circle()
                    .fill(DUColorPrimitives.Neutral.black.opacity(0.28))
                    .frame(width: 64, height: 64)
                    .overlay(
                        Image(systemName: "play.fill")
                            .font(.du(.titleStrong))
                            .foregroundColor(MallPalette(theme: theme).inverseText)
                            .offset(x: 2)
                    )
            }
        }
        .background(MallPalette(theme: theme).panelBackground)
    }
}

private struct MallProductPrimaryThumbnailStrip: View {
    @Environment(\.duTheme) private var theme

    let group: MallProductDetailSpecificationGroup
    let selectedValueID: String?
    let availableValueIDs: Set<String>
    let typesSummary: String
    let onSelectValue: (String) -> Void

    var body: some View {
        HStack(spacing: DUSpacing.md) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DUSpacing.sm) {
                    ForEach(thumbnailValues) { value in
                        MallProductPrimaryThumbnailButton(
                            image: value.image,
                            isSelected: value.id == selectedValueID,
                            isEnabled: availableValueIDs.contains(value.id),
                            action: {
                                onSelectValue(value.id)
                            }
                        )
                    }
                }
            }

            Text(typesSummary)
                .font(.du(.metaStrong))
                .foregroundColor(MallPalette(theme: theme).tertiaryText)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var thumbnailValues: [MallProductDetailSpecificationValue] {
        group.values.filter { $0.image != nil }
    }
}

private struct MallProductPrimaryThumbnailButton: View {
    @Environment(\.duTheme) private var theme

    let image: MallImageSource?
    let isSelected: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: DURadius.md, style: .continuous)
                .fill(MallPalette(theme: theme).panelBackground)
                .frame(width: 40, height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: DURadius.md, style: .continuous)
                        .stroke(
                            isSelected ? MallPalette(theme: theme).accent : MallPalette(theme: theme).defaultBorder,
                            lineWidth: isSelected ? 2 : 1
                        )
                )
                .overlay {
                    if let image {
                        MallImageView(
                            image: image,
                            cornerRadius: 11,
                            cropsBitmapToFill: true,
                            bitmapFillScale: 1.02
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }
                }
                .opacity(isEnabled ? 1 : 0.35)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

private struct MallProductSummaryCard: View {
    @Environment(\.duTheme) private var theme

    let saleLabel: String
    let priceText: String
    let countdownLabel: String
    let saleEndsText: String
    let title: String
    let subtitle: String

    var body: some View {
        let palette = MallPalette(theme: theme)

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: DUSpacing.md) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(saleLabel)
                        .font(.du(.labelEmphasized))
                        .foregroundColor(palette.inverseText.opacity(0.92))

                    Text(priceText)
                        .font(.du(.heroStrong))
                        .foregroundColor(palette.inverseText)

                    Text("AED")
                        .font(.du(.captionEmphasized))
                        .foregroundColor(palette.inverseText.opacity(0.92))
                }
                .environment(\.layoutDirection, .leftToRight)

                Spacer(minLength: DUSpacing.md)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(countdownLabel)
                        .font(.du(.tiny))
                        .foregroundColor(palette.inverseText.opacity(0.82))

                    Text(saleEndsText)
                        .font(.du(.metaEmphasized))
                        .foregroundColor(palette.inverseText)
                        .multilineTextAlignment(.trailing)
                }
            }
            .padding(.horizontal, DUSpacing.lg)
            .padding(.vertical, DUSpacing.md)
            .background(palette.badgeGradient(for: .sale))
            .clipShape(RoundedRectangle(cornerRadius: DURadius.control, style: .continuous))
            .padding(.horizontal, DUSpacing.md)
            .padding(.top, DUSpacing.md)

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.du(.titleStrong))
                    .foregroundColor(palette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.du(.body))
                    .foregroundColor(palette.accent)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, DUSpacing.lg)
            .padding(.top, DUSpacing.lg)
            .padding(.bottom, DUSpacing.lg)
        }
        .background(palette.panelBackground)
        .overlay(alignment: .bottom) {
            // 价格卡只保留下边分隔线，顶部与缩略图条直接衔接。
            Rectangle()
                .fill(palette.subtleBorder)
                .frame(height: 1)
        }
    }
}

private struct MallProductInfoPanel: View {
    @Environment(\.duTheme) private var theme

    let selectedLabel: String
    let selectedValue: String
    let shipmentLabel: String
    let shipmentValue: String
    let deliveredToLabel: String
    let deliveredToValue: String
    let onSelected: () -> Void
    let onShipment: () -> Void
    let onDeliveredTo: () -> Void

    var body: some View {
        VStack(spacing: 1) {
            MallProductInfoRow(
                label: selectedLabel,
                value: selectedValue,
                action: onSelected
            )

            MallProductInfoRow(
                label: shipmentLabel,
                value: shipmentValue,
                action: onShipment
            )

            MallProductInfoRow(
                label: deliveredToLabel,
                value: deliveredToValue,
                action: onDeliveredTo
            )
        }
        .background(MallPalette(theme: theme).panelBackground)
        .overlay(
            Rectangle()
                .stroke(MallPalette(theme: theme).defaultBorder, lineWidth: 1)
        )
    }
}

private struct MallProductInfoRow: View {
    @Environment(\.duTheme) private var theme

    let label: String
    let value: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: DUSpacing.md) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(label)
                        .font(.du(.metaStrong))
                        .foregroundColor(MallPalette(theme: theme).tertiaryText)

                    Text(value)
                        .font(.du(.body))
                        .foregroundColor(MallPalette(theme: theme).primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Image(systemName: "chevron.right")
                    .font(.du(.labelEmphasized))
                    .foregroundColor(MallPalette(theme: theme).disabledText)
                    .padding(.top, DUSpacing.sm)
            }
            .padding(.horizontal, DUSpacing.lg)
            .padding(.vertical, DUSpacing.compact)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct MallProductBottomActionBar: View {
    @Environment(\.duTheme) private var theme

    let cartBadgeCount: Int
    let homeTitle: String
    let cartTitle: String
    let addToCartTitle: String
    let buyNowTitle: String
    let buyNowPriceText: String
    let bottomSafeInset: CGFloat
    let onHome: () -> Void
    let onCart: () -> Void
    let onAddToCart: () -> Void
    let onBuyNow: () -> Void

    var body: some View {
        let palette = MallPalette(theme: theme)
        let bottomActionBarMetrics = MallBottomActionBarLayout.metrics(
            buttonHeight: MallProductDetailLayout.bottomActionBarButtonHeight,
            bottomSafeInset: bottomSafeInset
        )

        HStack(spacing: 8) {
            HStack(spacing: 8) {
                MallProductBottomIconAction(
                    systemName: "house",
                    title: homeTitle,
                    badgeCount: nil,
                    action: onHome
                )

                MallProductBottomIconAction(
                    systemName: "cart",
                    title: cartTitle,
                    badgeCount: cartBadgeCount,
                    action: onCart
                )
            }

            HStack(spacing: 8) {
                Button(action: onAddToCart) {
                    Text(addToCartTitle)
                        .font(.du(.labelEmphasized))
                        .foregroundColor(palette.inverseText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(palette.badgeGradient(for: .sale))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button(action: onBuyNow) {
                    VStack(spacing: 1) {
                        Text(buyNowTitle)
                            .font(.du(.microStrong))
                            .foregroundColor(palette.inverseText.opacity(0.94))

                        Text("\(buyNowPriceText) AED")
                            .font(.du(.tinyEmphasized))
                            .foregroundColor(palette.inverseText)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(palette.badgeGradient(for: .brand))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DUSpacing.md)
        .padding(.top, bottomActionBarMetrics.topPadding)
        .padding(.bottom, bottomActionBarMetrics.bottomPadding)
        .background(palette.panelBackground)
        .offset(y: bottomActionBarMetrics.verticalOffset)
    }
}

private struct MallProductBottomIconAction: View {
    @Environment(\.duTheme) private var theme

    let systemName: String
    let title: String
    let badgeCount: Int?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: systemName)
                        .font(.du(.bodyLargeSemibold))
                        .foregroundColor(MallPalette(theme: theme).primaryText)

                    if let badgeCount, badgeCount > 0 {
                        Text("\(badgeCount)")
                            .font(.du(.microStrong))
                            .foregroundColor(MallPalette(theme: theme).inverseText)
                            .padding(.horizontal, DUSpacing.xs)
                            .frame(height: 16)
                            .background(MallPalette(theme: theme).badgeGradient(for: .sale))
                            .clipShape(Capsule())
                            .offset(x: 10, y: -6)
                    }
                }

                Text(title)
                    .font(.du(.micro))
                    .foregroundColor(MallPalette(theme: theme).accent)
                    .lineLimit(1)
            }
            .frame(width: 50, height: 34)
        }
        .buttonStyle(.plain)
    }
}

private struct MallProductHTMLSection: View {
    @Environment(\.duTheme) private var theme
    @EnvironmentObject private var languageStore: AppLanguageStore

    let title: String
    let html: String
    let language: AppLanguage
    let onOpenImageURL: (String) -> Void

    @State private var contentHeight: CGFloat = 1
    @State private var loadState: MallProductHTMLLoadState = .loading
    @State private var reloadToken = UUID()

    var body: some View {
        let palette = MallPalette(theme: theme)

        VStack(alignment: .leading, spacing: DUSpacing.md) {
            Text(title)
                .font(.du(.headline))
                .foregroundColor(palette.primaryText)
                .padding(.horizontal, DUSpacing.lg)
                .padding(.top, DUSpacing.lg)

            ZStack {
                MallProductHTMLWebView(
                    html: html,
                    language: language,
                    contentHeight: $contentHeight,
                    loadState: $loadState,
                    reloadToken: reloadToken,
                    onOpenImageURL: onOpenImageURL
                )
                .frame(height: max(contentHeight, 1))
                .opacity(loadState == .failed ? 0 : 1)

                if loadState == .loading {
                    VStack(spacing: DUSpacing.sm) {
                        ProgressView()

                        Text(languageStore.string("mall.detail.html.loading"))
                            .font(.du(.label))
                            .foregroundColor(palette.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, DUSpacing.lg)
                    .padding(.vertical, DUSpacing.xxl)
                } else if loadState == .failed {
                    VStack(spacing: DUSpacing.sm) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.du(.headline))
                            .foregroundColor(theme.colors.status.warning)

                        Text(languageStore.string("mall.detail.html.error"))
                            .font(.du(.label))
                            .foregroundColor(palette.secondaryText)
                            .multilineTextAlignment(.center)

                        Button {
                            loadState = .loading
                            reloadToken = UUID()
                        } label: {
                            Text(languageStore.string("common.retry"))
                                .font(.du(.labelEmphasized))
                                .foregroundColor(palette.inverseText)
                                .padding(.horizontal, DUSpacing.lg)
                                .frame(height: 36)
                                .background(palette.badgeGradient(for: .sale))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, DUSpacing.lg)
                    .padding(.vertical, DUSpacing.xxl)
                }
            }
            .padding(.bottom, DUSpacing.lg)
            .background(palette.panelBackground)
        }
        .background(palette.panelBackground)
    }
}

private enum MallProductHTMLLoadState {
    case loading
    case loaded
    case failed
}

private struct MallProductHTMLWebView: UIViewRepresentable {
    let html: String
    let language: AppLanguage
    @Binding var contentHeight: CGFloat
    @Binding var loadState: MallProductHTMLLoadState
    let reloadToken: UUID
    let onOpenImageURL: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            contentHeight: $contentHeight,
            loadState: $loadState,
            onOpenImageURL: onOpenImageURL
        )
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.websiteDataStore = .default()
        configuration.userContentController.add(context.coordinator, name: Coordinator.imagePreviewHandlerName)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        context.coordinator.load(html: html, language: language, into: webView, reloadToken: reloadToken)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onOpenImageURL = onOpenImageURL
        context.coordinator.load(html: html, language: language, into: webView, reloadToken: reloadToken)
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(
            forName: Coordinator.imagePreviewHandlerName
        )
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        static let imagePreviewHandlerName = "mallImagePreview"

        @Binding private var contentHeight: CGFloat
        @Binding private var loadState: MallProductHTMLLoadState
        var onOpenImageURL: (String) -> Void
        private var lastReloadToken: UUID?

        init(
            contentHeight: Binding<CGFloat>,
            loadState: Binding<MallProductHTMLLoadState>,
            onOpenImageURL: @escaping (String) -> Void
        ) {
            _contentHeight = contentHeight
            _loadState = loadState
            self.onOpenImageURL = onOpenImageURL
        }

        func load(
            html: String,
            language: AppLanguage,
            into webView: WKWebView,
            reloadToken: UUID
        ) {
            guard lastReloadToken != reloadToken else {
                return
            }

            lastReloadToken = reloadToken
            loadState = .loading
            contentHeight = 1
            webView.loadHTMLString(
                wrappedHTMLDocument(body: html, language: language),
                baseURL: nil
            )
        }

        func webView(
            _ webView: WKWebView,
            didFinish navigation: WKNavigation!
        ) {
            webView.evaluateJavaScript("document.documentElement.scrollHeight") { result, _ in
                let resolvedHeight = (result as? CGFloat)
                    ?? (result as? Double).map { CGFloat($0) }
                    ?? 1

                Task { @MainActor in
                    self.contentHeight = max(resolvedHeight, 1)
                    self.loadState = .loaded
                }
            }
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            reportFailure(for: error)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            reportFailure(for: error)
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard
                message.name == Self.imagePreviewHandlerName,
                let imageURLString = message.body as? String
            else {
                return
            }

            Task { @MainActor in
                onOpenImageURL(imageURLString)
            }
        }

        private func reportFailure(for error: Error) {
            let nsError = error as NSError
            guard nsError.code != NSURLErrorCancelled else {
                return
            }

            Task { @MainActor in
                loadState = .failed
            }
        }

        private func wrappedHTMLDocument(
            body: String,
            language: AppLanguage
        ) -> String {
            let direction = language == .arabic ? "rtl" : "ltr"

            return """
            <!DOCTYPE html>
            <html lang="\(language.rawValue)" dir="\(direction)">
            <head>
              <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0" />
              <style>
                :root {
                  color-scheme: light;
                }
                body {
                  margin: 0;
                  padding: 0 16px 16px 16px;
                  font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                  color: #1f2d3d;
                  background: #ffffff;
                  line-height: 1.55;
                  overflow-x: hidden;
                }
                .mall-detail {
                  display: block;
                }
                .eyebrow {
                  margin: 0 0 10px 0;
                  font-size: 12px;
                  font-weight: 700;
                  color: #ff3359;
                }
                h2 {
                  margin: 0 0 12px 0;
                  font-size: 20px;
                  line-height: 1.3;
                }
                p {
                  margin: 0 0 14px 0;
                  font-size: 15px;
                  color: #48576b;
                }
                img {
                  width: calc(100% + 32px);
                  max-width: none;
                  height: auto;
                  display: block;
                  margin: 0 -16px 14px -16px;
                  background: #f5f7fa;
                  cursor: zoom-in;
                }
              </style>
            </head>
            <body>
              \(body)
              <script>
                document.addEventListener('click', function(event) {
                  const target = event.target;
                  if (!(target instanceof HTMLImageElement)) {
                    return;
                  }

                  const imageURL = target.currentSrc || target.src;
                  if (!imageURL) {
                    return;
                  }

                  event.preventDefault();
                  window.webkit.messageHandlers.\(Self.imagePreviewHandlerName).postMessage(imageURL);
                });
              </script>
            </body>
            </html>
            """
        }
    }
}

private struct MallProductDetailLoadingView: View {
    @Environment(\.duTheme) private var theme
    @EnvironmentObject private var languageStore: AppLanguageStore

    var body: some View {
        VStack(spacing: DUSpacing.lg) {
            ProgressView()

            Text(languageStore.string("mall.detail.state.loading"))
                .font(.du(.bodyLargeSemibold))
                .foregroundColor(MallPalette(theme: theme).secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct MallProductDetailFailureView: View {
    @Environment(\.duTheme) private var theme
    @EnvironmentObject private var languageStore: AppLanguageStore

    let onRetry: () -> Void

    var body: some View {
        DUStateView(
            systemImage: "exclamationmark.triangle",
            iconColor: theme.colors.status.warning,
            title: languageStore.string("mall.detail.state.error.title"),
            subtitle: languageStore.string("mall.detail.state.error.subtitle"),
            actionTitle: languageStore.string("common.retry")
        ) {
            onRetry()
        }
    }
}
