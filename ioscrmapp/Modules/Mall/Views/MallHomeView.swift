import SwiftUI

struct MallHomeView: View {
    @Environment(\.duTheme) private var theme
    @EnvironmentObject private var languageStore: AppLanguageStore
    @EnvironmentObject private var homeChromeState: HomeChromeState

    @ObservedObject var viewModel: MallViewModel
    let onBackToAppHome: () -> Void

    @State private var selectedCategoryID = ""
    @State private var selectedSubcategoryID = ""
    @State private var isSearchPresented = false
    @State private var isCategoryPresented = false
    @State private var isCartPresented = false
    @State private var selectedProduct: MallProduct?
    @State private var searchResultRoute: MallBrowseSearchRoute?
    @State private var productSectionViewportHeight: CGFloat = 0
    @State private var hasArmedProductSectionLoadMore = false

    private let recommendedCategoryID = "mall-recommended"
    private let mallHomeBottomTabBarKey = "mall-home"
    private let contentTopAnchorID = "mall-home-content-top"
    private let scrollCoordinateSpaceName = "MallHomeScroll"
    private let maxVisibleThirdLevelCount = 15

    var body: some View {
        Group {
            switch viewModel.screenState {
            case .idle, .loading:
                loadingView
            case let .failed(message):
                errorView(message)
            case .loaded:
                contentView
            }
        }
        .background(MallPalette(theme: theme).canvasBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .task {
            await MainActor.run {
                homeChromeState.hideBottomTabBar(for: mallHomeBottomTabBarKey)
            }
            await viewModel.loadIfNeeded()
            syncSelection()
            await loadSelectedProductFeed(forceRefresh: false)
        }
        .onAppear {
            Task { @MainActor in
                await Task.yield()
                homeChromeState.hideBottomTabBar(for: mallHomeBottomTabBarKey)
            }
        }
        .onDisappear {
            homeChromeState.showBottomTabBar(for: mallHomeBottomTabBarKey)
        }
        .onChange(of: viewModel.homeSnapshot?.defaultCategoryID ?? "") { _ in
            syncSelection()
            Task {
                await loadSelectedProductFeed(forceRefresh: false)
            }
        }
    }

    private var contentView: some View {
        GeometryReader { proxy in
            ScrollViewReader { scrollProxy in
                VStack(spacing: 0) {
                    headerView(topInset: proxy.safeAreaInsets.top)
                        .background(
                            headerBackground
                                .ignoresSafeArea(edges: .top)
                        )

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: DUSpacing.lg) {
                            Color.clear
                                .frame(height: 0)
                                .id(contentTopAnchorID)

                            if isRecommendationSelected {
                                recommendationContent(containerWidth: proxy.size.width)
                            } else {
                                standardCategoryContent
                            }
                        }
                        .padding(.top, DUSpacing.md)
                        .padding(.bottom, DUSpacing.xxl)
                    }
                    .coordinateSpace(name: scrollCoordinateSpaceName)
                    .background(
                        GeometryReader { geometry in
                            Color.clear
                                .onAppear {
                                    productSectionViewportHeight = geometry.size.height
                                }
                                .onChange(of: geometry.size.height) { value in
                                    productSectionViewportHeight = value
                                }
                        }
                    )
                    .refreshable {
                        await viewModel.refresh()
                        syncSelection()
                        await loadSelectedProductFeed(forceRefresh: true)
                    }
                    .overlay(navigationLinks)
                }
                .background(MallPalette(theme: theme).canvasBackground.ignoresSafeArea())
                .ignoresSafeArea(edges: .top)
                .onChange(of: selectedCategoryID) { _ in
                    withAnimation(.easeInOut(duration: 0.22)) {
                        scrollProxy.scrollTo(contentTopAnchorID, anchor: .top)
                    }
                    Task {
                        await loadSelectedProductFeed(forceRefresh: false)
                    }
                }
            }
        }
    }

    private func headerView(topInset: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.sm) {
            Color.clear
                .frame(height: max(topInset, DUSpacing.sm))

            homeSearchRow
            primaryCategoryBar
        }
        .padding(.horizontal, DUSpacing.md)
        .padding(.bottom, DUSpacing.sm)
    }

    private var headerBackground: some View {
        theme.colors.gradient.brand
    }

    private var homeSearchRow: some View {
        let palette = MallPalette(theme: theme)

        return HStack(spacing: DUSpacing.md) {
            Button(action: onBackToAppHome) {
                RoundedRectangle(cornerRadius: DURadius.control, style: .continuous)
                    .fill(palette.panelBackground.opacity(theme.resolvedColorScheme == .dark ? 0.88 : 0.96))
                    .frame(width: 50, height: 50)
                    .shadow(color: palette.spotlightElevation.color, radius: palette.spotlightElevation.radius, x: palette.spotlightElevation.x, y: palette.spotlightElevation.y)
                    .overlay(
                        Image(systemName: "chevron.left")
                            .font(.du(.headline))
                            .foregroundColor(palette.accent)
                    )
            }
            .buttonStyle(.plain)

            Button {
                isSearchPresented = true
            } label: {
                HStack(spacing: DUSpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.du(.bodyLargeSemibold))
                        .foregroundColor(palette.tertiaryText)

                    Text(homeSnapshot?.searchPlaceholder.value(for: languageStore.currentLanguage) ?? "")
                        .font(.du(.meta))
                        .foregroundColor(palette.secondaryText)
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, DUSpacing.md)
                .frame(height: 46)
                .background(palette.panelBackground.opacity(theme.resolvedColorScheme == .dark ? 0.88 : 0.96))
                .clipShape(RoundedRectangle(cornerRadius: DURadius.control, style: .continuous))
                .shadow(color: palette.liftedElevation.color, radius: palette.liftedElevation.radius, x: palette.liftedElevation.x, y: palette.liftedElevation.y)
            }
            .buttonStyle(.plain)

            Button {
                isCartPresented = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: DURadius.control, style: .continuous)
                        .fill(palette.panelBackground.opacity(theme.resolvedColorScheme == .dark ? 0.88 : 0.96))
                        .frame(width: 50, height: 50)
                        .shadow(color: palette.spotlightElevation.color, radius: palette.spotlightElevation.radius, x: palette.spotlightElevation.x, y: palette.spotlightElevation.y)
                        .overlay(
                            Image(systemName: "cart.fill")
                                .font(.du(.headline))
                                .foregroundColor(palette.accent)
                        )

                    if viewModel.cartBadgeCount > 0 {
                        Text("\(viewModel.cartBadgeCount)")
                            .font(.du(.tinyEmphasized))
                            .foregroundColor(palette.inverseText)
                            .padding(.horizontal, DUSpacing.smd - 1)
                            .frame(height: 18)
                            .background(palette.badgeGradient(for: .sale))
                            .clipShape(Capsule())
                            .offset(x: 6, y: -6)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var primaryCategoryBar: some View {
        let palette = MallPalette(theme: theme)

        return HStack(spacing: DUSpacing.md) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DUSpacing.lg) {
                    ForEach(primaryTabs) { tab in
                        Button {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                selectPrimaryCategory(tab.id)
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Text(tab.title)
                                    .font(.du(.bodyStrong))
                                    .foregroundColor(
                                        tab.id == selectedCategoryID
                                            ? palette.inverseText
                                            : palette.inverseText.opacity(0.78)
                                    )
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)

                                Capsule()
                                    .fill(tab.id == selectedCategoryID ? palette.inverseText : .clear)
                                    .frame(width: 20, height: 4)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
            }

            categoryEntryButton
        }
    }

    private var categoryEntryButton: some View {
        let palette = MallPalette(theme: theme)

        return Button {
            isCategoryPresented = true
        } label: {
            VStack(spacing: 6) {
                Text(languageStore.string("mall.category.button"))
                    .font(.du(.bodyStrong))
                    .foregroundColor(palette.inverseText.opacity(0.82))
                    .lineLimit(1)

                Capsule()
                    .fill(.clear)
                    .frame(width: 20, height: 4)
            }
        }
        .buttonStyle(.plain)
    }

    private func recommendationContent(containerWidth: CGFloat) -> some View {
        VStack(spacing: DUSpacing.lg) {
            recommendationCarouselSection(containerWidth: containerWidth)
            recommendationActivitySection
            productSection(
                title: homeSnapshot?.recommendation.productSectionTitle.value(for: languageStore.currentLanguage) ?? "",
                subtitle: nil
            )
        }
    }

    @ViewBuilder
    private var standardCategoryContent: some View {
        if currentCategory != nil {
            thirdLevelDirectoryGridSection
            productSection(
                title: currentCategory?.title.value(for: languageStore.currentLanguage) ?? "",
                subtitle: nil
            )
        }
    }

    @ViewBuilder
    private func recommendationCarouselSection(containerWidth: CGFloat) -> some View {
        let cards = homeSnapshot?.recommendation.highlightCards ?? []

        // 后端没返回精选卡片时，整块区域直接隐藏，避免首页出现空标题或占位。
        if !cards.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                MallHomeHighlightCarouselView(
                    cards: cards,
                    containerWidth: containerWidth
                ) { card in
                    showProduct(id: card.productID)
                }
            }
        }
    }

    @ViewBuilder
    private var recommendationActivitySection: some View {
        // 首页活动区最多展示 3 张卡片，更多内容交由后续页面承接。
        let activityCards = Array((homeSnapshot?.recommendation.activityCards ?? []).prefix(3))

        // 活动卡片为空时整块隐藏，保持首页节奏和信息密度稳定。
        if !activityCards.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.flexible(), spacing: DUSpacing.md, alignment: .top),
                        count: min(activityCards.count, 3)
                    ),
                    spacing: DUSpacing.md
                ) {
                    ForEach(activityCards) { card in
                        MallHomeActivityCardView(card: card) {
                            handleActivitySelection(card)
                        }
                    }
                }
                .padding(.horizontal, DUSpacing.md)
            }
        }
    }

    private var thirdLevelDirectoryGridSection: some View {
        VStack(alignment: .leading, spacing: DUSpacing.lg) {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: DUSpacing.sm), count: 5),
                spacing: DUSpacing.md
            ) {
                ForEach(thirdLevelDirectoryGridItems) { item in
                    switch item {
                    case let .directory(directory):
                        MallHomeSubcategoryTileView(
                            title: directory.title.value(for: languageStore.currentLanguage),
                            image: directory.image,
                            isSelected: false,
                            isMoreTile: false
                        ) {
                            openSearchResult(
                                query: directory.title.value(for: languageStore.currentLanguage),
                                categoryID: directory.categoryID
                            )
                        }
                    case .more:
                        MallHomeSubcategoryTileView(
                            title: moreTileTitle,
                            image: nil,
                            isSelected: false,
                            isMoreTile: true
                        ) {
                            isCategoryPresented = true
                        }
                    }
                }
            }
        }
        .padding(DUSpacing.lg)
        .duCardStyle()
        .padding(.horizontal, DUSpacing.md)
    }

    @ViewBuilder
    private func productSection(
        title: String,
        subtitle: String?
    ) -> some View {
        let palette = MallPalette(theme: theme)

        VStack(alignment: .leading, spacing: DUSpacing.md) {
            if !title.isEmpty || ((subtitle?.isEmpty) == false) {
                HStack(alignment: .top, spacing: DUSpacing.sm) {
                    if !title.isEmpty {
                        Text(title)
                            .font(.du(.headline))
                            .foregroundColor(palette.primaryText)
                    }

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.du(.metaStrong))
                            .foregroundColor(theme.colors.status.error)
                            .padding(.horizontal, DUSpacing.base)
                            .frame(height: 24)
                            .background(palette.chipSelectedBackground)
                            .clipShape(Capsule())
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, DUSpacing.md)
            }

            switch viewModel.homeProductFeedState {
            case .idle, .loading:
                productSectionLoadingView
                    .padding(.horizontal, DUSpacing.md)
            case let .failed(message):
                productSectionFailureView(message)
                    .padding(.horizontal, DUSpacing.md)
            case .loaded:
                if currentHomeProducts.isEmpty {
                    productSectionEmptyView
                        .padding(.horizontal, DUSpacing.md)
                } else {
                    MallScrollActivationTrigger(
                        coordinateSpaceName: scrollCoordinateSpaceName,
                        isArmed: hasArmedProductSectionLoadMore
                    ) {
                        hasArmedProductSectionLoadMore = true
                    }

                    MallProductFeedGrid(
                        products: currentHomeProducts,
                        rowSpacing: DUSpacing.sm,
                        oddItemTopPadding: DUSpacing.sm
                    ) { product in
                        selectedProduct = product
                    }
                    .padding(.horizontal, DUSpacing.md)

                    productSectionFooter

                    MallScrollLoadMoreTrigger(
                        coordinateSpaceName: scrollCoordinateSpaceName,
                        viewportHeight: productSectionViewportHeight,
                        isArmed: hasArmedProductSectionLoadMore,
                        canTrigger: canTriggerHomeProductLoadMore
                    ) {
                        guard let lastProduct = currentHomeProducts.last else {
                            return
                        }
                        Task {
                            await viewModel.loadMoreHomeProductsIfNeeded(currentProduct: lastProduct)
                        }
                    }
                }
            }
        }
    }

    private var productSectionLoadingView: some View {
        let palette = MallPalette(theme: theme)

        return HStack(spacing: DUSpacing.sm) {
            ProgressView()

            Text(languageStore.string("mall.state.loading.title"))
                .font(.du(.label))
                .foregroundColor(palette.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DUSpacing.xl)
        .duCardStyle()
    }

    private func productSectionFailureView(_ message: LocalizedTextValue) -> some View {
        let palette = MallPalette(theme: theme)

        return VStack(spacing: DUSpacing.md) {
            Image(systemName: "wifi.exclamationmark")
                .font(.du(.headline))
                .foregroundColor(theme.colors.brand.magenta)

            Text(languageStore.string(message))
                .font(.du(.label))
                .foregroundColor(palette.secondaryText)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    await loadSelectedProductFeed(forceRefresh: true)
                }
            } label: {
                Text(languageStore.string("common.retry"))
                    .font(.du(.labelEmphasized))
                    .foregroundColor(palette.inverseText)
                    .padding(.horizontal, DUSpacing.lg)
                    .frame(height: 36)
                    .background(theme.colors.gradient.brand)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DUSpacing.xl)
        .padding(.horizontal, DUSpacing.lg)
        .duCardStyle()
    }

    private var productSectionEmptyView: some View {
        let palette = MallPalette(theme: theme)

        return VStack(spacing: DUSpacing.sm) {
            Image(systemName: "shippingbox")
                .font(.du(.headline))
                .foregroundColor(theme.colors.brand.primary)

            Text(languageStore.string("mall.search.empty.title"))
                .font(.du(.bodyEmphasized))
                .foregroundColor(palette.primaryText)

            Text(languageStore.string("mall.search.empty.subtitle"))
                .font(.du(.meta))
                .foregroundColor(palette.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DUSpacing.xl)
        .padding(.horizontal, DUSpacing.lg)
        .duCardStyle()
    }

    @ViewBuilder
    private var productSectionFooter: some View {
        MallProductFeedLoadMoreFooter(
            isLoading: viewModel.isLoadingMoreHomeProducts,
            errorMessage: viewModel.homeProductFeedLoadMoreError,
            retryTint: theme.colors.status.error
        ) {
            Task {
                await viewModel.retryLoadingMoreHomeProducts()
            }
        }
    }

    private func errorView(_ message: LocalizedTextValue) -> some View {
        DUStateView(
            systemImage: "wifi.exclamationmark",
            iconColor: theme.colors.brand.magenta,
            title: languageStore.string("mall.state.error.title"),
            subtitle: languageStore.string(message),
            actionTitle: languageStore.string("common.retry")
        ) {
            Task {
                await viewModel.reload()
                syncSelection()
                await loadSelectedProductFeed(forceRefresh: true)
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: DUSpacing.lg) {
            ProgressView()
                .progressViewStyle(.circular)

            Text(languageStore.string("mall.state.loading.title"))
                .font(.du(.bodyLargeSemibold))
                .foregroundColor(MallPalette(theme: theme).secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                destination: MallCategoryView(
                    viewModel: viewModel,
                    initialCategoryID: categoryPageCategoryID,
                    initialSubcategoryID: nil
                ),
                isActive: $isCategoryPresented
            ) {
                EmptyView()
            }
            .hidden()

            NavigationLink(
                destination: searchResultDestination,
                isActive: searchResultPresentedBinding
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

            NavigationLink(
                destination: productDetailDestination,
                isActive: selectedProductPresentedBinding
            ) {
                EmptyView()
            }
            .hidden()
        }
    }

    private var homeSnapshot: MallHomeSnapshot? {
        viewModel.homeSnapshot
    }

    private var isRecommendationSelected: Bool {
        selectedCategoryID == recommendedCategoryID || selectedCategoryID.isEmpty
    }

    private var primaryTabs: [MallHomePrimaryTab] {
        var tabs = [
            MallHomePrimaryTab(
                id: recommendedCategoryID,
                title: homeSnapshot?.recommendation.tabTitle.value(for: languageStore.currentLanguage) ?? recommendedFallbackTitle
            )
        ]

        tabs += (homeSnapshot?.primaryCategories ?? []).map { category in
            MallHomePrimaryTab(
                id: category.id,
                title: category.title.value(for: languageStore.currentLanguage)
            )
        }

        return tabs
    }

    private var currentCategory: MallPrimaryCategory? {
        guard !isRecommendationSelected else {
            return nil
        }

        return viewModel.primaryCategory(id: selectedCategoryID)
    }

    private var currentHomeProducts: [MallProduct] {
        viewModel.homeProductFeed?.products ?? []
    }

    private var canTriggerHomeProductLoadMore: Bool {
        productSectionViewportHeight > 0
            && viewModel.homeProductFeed?.hasMore == true
            && !viewModel.isLoadingMoreHomeProducts
            && viewModel.homeProductFeedLoadMoreError == nil
    }

    private var thirdLevelDirectoryEntries: [MallHomeThirdLevelDirectory] {
        let subcategories = currentCategory?.subcategories ?? []

        return subcategories.flatMap { subcategory in
            subcategory.thirdCategories.map { item in
                MallHomeThirdLevelDirectory(
                    id: "\(subcategory.id)-\(item.id)",
                    title: item.title,
                    image: item.image,
                    categoryID: item.id
                )
            }
        }
    }

    private var thirdLevelDirectoryGridItems: [MallHomeThirdLevelGridItem] {
        guard thirdLevelDirectoryEntries.count > maxVisibleThirdLevelCount else {
            return thirdLevelDirectoryEntries.map(MallHomeThirdLevelGridItem.directory)
        }

        let visibleItems = thirdLevelDirectoryEntries.prefix(maxVisibleThirdLevelCount - 1)
        return visibleItems.map(MallHomeThirdLevelGridItem.directory) + [.more]
    }

    private var categoryPageCategoryID: String {
        if let currentCategory {
            return currentCategory.id
        }

        return homeSnapshot?.defaultCategoryID ?? ""
    }

    private var recommendedFallbackTitle: String {
        switch languageStore.currentLanguage {
        case .simplifiedChinese:
            return "推荐"
        case .english:
            return "Featured"
        case .arabic:
            return "موصى به"
        }
    }

    private var moreTileTitle: String {
        switch languageStore.currentLanguage {
        case .simplifiedChinese:
            return "更多"
        case .english:
            return "More"
        case .arabic:
            return "المزيد"
        }
    }

    private func selectPrimaryCategory(_ categoryID: String) {
        if categoryID == recommendedCategoryID {
            selectedCategoryID = recommendedCategoryID
            selectedSubcategoryID = ""
            return
        }

        selectedCategoryID = categoryID
        selectedSubcategoryID = ""
    }

    private func handleActivitySelection(_ card: MallHomeActivityCard) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            selectedCategoryID = card.categoryID
            selectedSubcategoryID = card.subcategoryID
                ?? viewModel.primaryCategory(id: card.categoryID)?.subcategories.first?.id
                ?? ""
        }
    }

    private func showProduct(id: String) {
        selectedProduct = currentHomeProducts.first { $0.id == id }
            ?? homeSnapshot?.products.first { $0.id == id }
    }

    private func openSearchResult(
        query: String,
        categoryID: String?
    ) {
        searchResultRoute = MallBrowseSearchRoute(
            query: query,
            categoryID: categoryID
        )
    }

    private func syncSelection() {
        guard homeSnapshot != nil else {
            return
        }

        if selectedCategoryID.isEmpty {
            selectedCategoryID = recommendedCategoryID
        }

        guard !isRecommendationSelected else {
            selectedSubcategoryID = ""
            return
        }

        guard let currentCategory = viewModel.primaryCategory(id: selectedCategoryID) else {
            selectedCategoryID = recommendedCategoryID
            selectedSubcategoryID = ""
            return
        }

        if !currentCategory.subcategories.contains(where: { $0.id == selectedSubcategoryID }) {
            selectedSubcategoryID = ""
        }
    }

    private func loadSelectedProductFeed(forceRefresh: Bool) async {
        guard homeSnapshot != nil else {
            return
        }

        resetProductSectionLoadMoreState()

        if isRecommendationSelected {
            await viewModel.loadHomeProductFeed(
                scene: .recommendation,
                categoryID: nil,
                forceRefresh: forceRefresh
            )
            return
        }

        await viewModel.loadHomeProductFeed(
            scene: .category,
            categoryID: currentCategory?.id ?? selectedCategoryID,
            forceRefresh: forceRefresh
        )
    }

    private func resetProductSectionLoadMoreState() {
        hasArmedProductSectionLoadMore = false
    }

    @ViewBuilder
    private var searchResultDestination: some View {
        if let searchResultRoute {
            MallSearchResultView(
                viewModel: viewModel,
                initialQuery: searchResultRoute.query,
                initialCategoryID: searchResultRoute.categoryID
            )
        } else {
            EmptyView()
        }
    }

    private var searchResultPresentedBinding: Binding<Bool> {
        Binding(
            get: { searchResultRoute != nil },
            set: { isPresented in
                if !isPresented {
                    searchResultRoute = nil
                }
            }
        )
    }

    @ViewBuilder
    private var productDetailDestination: some View {
        if let selectedProduct {
            MallProductDetailView(
                viewModel: viewModel,
                product: selectedProduct
            )
        } else {
            EmptyView()
        }
    }

    private var selectedProductPresentedBinding: Binding<Bool> {
        Binding(
            get: { selectedProduct != nil },
            set: { isPresented in
                if !isPresented {
                    selectedProduct = nil
                }
            }
        )
    }
}

private struct MallHomePrimaryTab: Identifiable {
    let id: String
    let title: String
}

private struct MallBrowseSearchRoute: Identifiable {
    let query: String
    let categoryID: String?

    var id: String {
        "\(query)-\(categoryID ?? "all")"
    }
}

private struct MallHomeThirdLevelDirectory: Identifiable {
    let id: String
    let title: MallLocalizedString
    let image: MallImageSource
    let categoryID: String
}

private enum MallHomeThirdLevelGridItem: Identifiable {
    case directory(MallHomeThirdLevelDirectory)
    case more

    var id: String {
        switch self {
        case let .directory(directory):
            return directory.id
        case .more:
            return "mall-more"
        }
    }
}

private struct MallHomeActivityCardView: View {
    @Environment(\.duTheme) private var theme
    @EnvironmentObject private var languageStore: AppLanguageStore

    private let imageBoxWidth: CGFloat = 96
    private let imageBoxHeight: CGFloat = 82

    let card: MallHomeActivityCard
    let action: () -> Void

    var body: some View {
        let palette = MallPalette(theme: theme)

        Button(action: action) {
            VStack(alignment: .leading, spacing: DUSpacing.sm) {
                Text(card.title.value(for: languageStore.currentLanguage))
                    .font(.du(.titleSmall))
                    .foregroundColor(palette.primaryText)
                    .lineLimit(2)

                Text(card.subtitle.value(for: languageStore.currentLanguage))
                    .font(.du(.caption))
                    .foregroundColor(palette.secondaryText)
                    .lineLimit(2)

                // 活动海报统一落在固定图片框里，超出边界直接裁掉，避免不同素材比例破坏卡片节奏。
                MallPromotionalIllustration(
                    image: card.image,
                    cornerRadius: 22,
                    contentMode: .fill,
                    contentScale: 1
                )
                    .frame(width: imageBoxWidth, height: imageBoxHeight)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(DUSpacing.lg)
            .frame(maxWidth: .infinity, minHeight: 188, alignment: .topLeading)
            .background(palette.panelBackground)
            .overlay(
                RoundedRectangle(cornerRadius: DURadius.sheetLarge, style: .continuous)
                    .stroke(palette.subtleBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: DURadius.sheetLarge, style: .continuous))
            .shadow(color: palette.cardElevation.color, radius: palette.cardElevation.radius, x: palette.cardElevation.x, y: palette.cardElevation.y)
        }
        .buttonStyle(.plain)
    }
}

private struct MallHomeSubcategoryTileView: View {
    @Environment(\.duTheme) private var theme

    let title: String
    let image: MallImageSource?
    let isSelected: Bool
    let isMoreTile: Bool
    let action: () -> Void

    var body: some View {
        let palette = MallPalette(theme: theme)

        Button(action: action) {
            VStack(spacing: DUSpacing.sm) {
                Group {
                    if let image {
                        MallImageView(
                            image: image,
                            cropsBitmapToFill: true,
                            bitmapFillScale: 1.12
                        )
                    } else {
                        RoundedRectangle(cornerRadius: DURadius.control, style: .continuous)
                            .fill(theme.colors.gradient.subtle)
                            .overlay(
                                Image(systemName: "ellipsis.circle.fill")
                                    .font(.du(.title))
                                    .foregroundColor(palette.accent)
                            )
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .clipShape(RoundedRectangle(cornerRadius: DURadius.control, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DURadius.control, style: .continuous)
                        .stroke(
                            isSelected
                                ? palette.badgeGradient(for: .sale)
                                : LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing),
                            lineWidth: isSelected ? 2 : 0
                        )
                )

                Text(title)
                    .font(.du(isSelected || isMoreTile ? .captionEmphasized : .caption))
                    .foregroundColor(
                        isSelected
                            ? theme.colors.status.error
                            : palette.secondaryText
                    )
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .buttonStyle(.plain)
    }
}
