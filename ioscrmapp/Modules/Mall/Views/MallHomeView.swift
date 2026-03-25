import SwiftUI

struct MallHomeView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore

    @ObservedObject var viewModel: MallViewModel

    @State private var selectedCategoryID = ""
    @State private var selectedSubcategoryID = ""
    @State private var isSearchPresented = false
    @State private var isCategoryPresented = false
    @State private var selectedProduct: MallProduct?
    @State private var searchResultRoute: MallBrowseSearchRoute?

    private let recommendedCategoryID = "mall-recommended"
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
        .background(DUTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .task {
            await viewModel.loadIfNeeded()
            syncSelection()
        }
        .onChange(of: viewModel.homeSnapshot?.defaultCategoryID ?? "") { _ in
            syncSelection()
        }
        .sheet(item: $selectedProduct) { product in
            MallProductTargetSheet(product: product)
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
                    .refreshable {
                        await viewModel.refresh()
                    }
                    .overlay(navigationLinks)
                }
                .background(DUTheme.background.ignoresSafeArea())
                .ignoresSafeArea(edges: .top)
                .onChange(of: selectedCategoryID) { _ in
                    withAnimation(.easeInOut(duration: 0.22)) {
                        scrollProxy.scrollTo(contentTopAnchorID, anchor: .top)
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
        MallTheme.headerGradient
    }

    private var homeSearchRow: some View {
        HStack(spacing: DUSpacing.md) {
            Button {
                isSearchPresented = true
            } label: {
                HStack(spacing: DUSpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.du(15, weight: .semibold))
                        .foregroundColor(DUTheme.inkTertiary)

                    Text(homeSnapshot?.searchPlaceholder.value(for: languageStore.currentLanguage) ?? "")
                        .font(.du(12, weight: .medium))
                        .foregroundColor(DUTheme.inkSecondary)
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, DUSpacing.md)
                .frame(height: 46)
                .background(Color.white.opacity(0.96))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color.black.opacity(0.1), radius: 16, x: 0, y: 8)
            }
            .buttonStyle(.plain)

            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.96))
                    .frame(width: 50, height: 50)
                    .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 10)
                    .overlay(
                        Image(systemName: "cart.fill")
                            .font(.du(20, weight: .semibold))
                            .foregroundColor(Color(hex: 0x156B92))
                    )

                if let cartBadgeCount = homeSnapshot?.cartBadgeCount, cartBadgeCount > 0 {
                    Text("\(cartBadgeCount)")
                        .font(.du(10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .frame(height: 18)
                        .background(Color(hex: 0xFF394D))
                        .clipShape(Capsule())
                        .offset(x: 6, y: -6)
                }
            }
        }
    }

    private var primaryCategoryBar: some View {
        HStack(spacing: DUSpacing.md) {
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
                                    .font(.du(14, weight: .semibold))
                                    .foregroundColor(tab.id == selectedCategoryID ? .white : .white.opacity(0.78))
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)

                                Capsule()
                                    .fill(tab.id == selectedCategoryID ? Color.white : .clear)
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
        Button {
            isCategoryPresented = true
        } label: {
            VStack(spacing: 6) {
                Text(languageStore.string("mall.category.button"))
                    .font(.du(14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.82))
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
                title: "",
                subtitle: nil,
                products: recommendedProducts
            )
        }
    }

    @ViewBuilder
    private var standardCategoryContent: some View {
        if currentCategory != nil {
            thirdLevelDirectoryGridSection
            productSection(
                title: currentCategory?.title.value(for: languageStore.currentLanguage) ?? "",
                subtitle: nil,
                products: currentProducts
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
        subtitle: String?,
        products: [MallProduct]
    ) -> some View {
        if !products.isEmpty {
            VStack(alignment: .leading, spacing: DUSpacing.md) {
                if !title.isEmpty || ((subtitle?.isEmpty) == false) {
                    HStack(alignment: .top, spacing: DUSpacing.sm) {
                        if !title.isEmpty {
                            Text(title)
                                .font(.du(20, weight: .bold))
                                .foregroundColor(DUTheme.ink)
                        }

                        if let subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.du(12, weight: .semibold))
                                .foregroundColor(Color(hex: 0xFF5163))
                                .padding(.horizontal, 10)
                                .frame(height: 24)
                                .background(Color(hex: 0xFFF0F1))
                                .clipShape(Capsule())
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, DUSpacing.md)
                }

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: DUSpacing.md),
                        GridItem(.flexible(), spacing: DUSpacing.md),
                    ],
                    spacing: DUSpacing.sm
                ) {
                    ForEach(products.indices, id: \.self) { index in
                        MallProductCard(product: products[index]) {
                            selectedProduct = products[index]
                        }
                        .padding(.top, index.isMultiple(of: 2) ? 0 : DUSpacing.sm)
                    }
                }
                .padding(.horizontal, DUSpacing.md)
            }
        }
    }

    private func errorView(_ message: LocalizedTextValue) -> some View {
        DUStateView(
            systemImage: "wifi.exclamationmark",
            iconColor: DUTheme.magenta,
            title: languageStore.string("mall.state.error.title"),
            subtitle: languageStore.string(message),
            actionTitle: languageStore.string("common.retry")
        ) {
            Task {
                await viewModel.reload()
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: DUSpacing.lg) {
            ProgressView()
                .progressViewStyle(.circular)

            Text(languageStore.string("mall.state.loading.title"))
                .font(.du(15, weight: .semibold))
                .foregroundColor(DUTheme.inkSecondary)
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

    private var currentProducts: [MallProduct] {
        guard let currentCategory else {
            return []
        }

        return viewModel.products(
            for: currentCategory.id,
            subcategoryID: nil
        )
    }

    private var recommendedProducts: [MallProduct] {
        let products = homeSnapshot?.products ?? []
        return Array(products.sorted(by: isHigherPriorityProduct).prefix(6))
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
        selectedProduct = homeSnapshot?.products.first { $0.id == id }
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

    private func isHigherPriorityProduct(_ lhs: MallProduct, _ rhs: MallProduct) -> Bool {
        if lhs.sortWeight != rhs.sortWeight {
            return lhs.sortWeight > rhs.sortWeight
        }
        if lhs.salesCount != rhs.salesCount {
            return lhs.salesCount > rhs.salesCount
        }
        return lhs.updatedAt > rhs.updatedAt
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

private struct MallHomeHighlightCarouselView: View {
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

private struct MallHomeActivityCardView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore

    private let imageBoxWidth: CGFloat = 96
    private let imageBoxHeight: CGFloat = 82

    let card: MallHomeActivityCard
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: DUSpacing.sm) {
                Text(card.title.value(for: languageStore.currentLanguage))
                    .font(.du(17, weight: .bold))
                    .foregroundColor(DUTheme.ink)
                    .lineLimit(2)

                Text(card.subtitle.value(for: languageStore.currentLanguage))
                    .font(.du(11, weight: .medium))
                    .foregroundColor(DUTheme.inkSecondary)
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
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.black.opacity(0.04), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 10)
        }
        .buttonStyle(.plain)
    }
}

private struct MallPromotionalIllustration: View {
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

private struct MallHomeSubcategoryTileView: View {
    let title: String
    let image: MallImageSource?
    let isSelected: Bool
    let isMoreTile: Bool
    let action: () -> Void

    var body: some View {
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
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: 0xE7F8FC), Color(hex: 0xEEF3FF)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Image(systemName: "ellipsis.circle.fill")
                                    .font(.du(24, weight: .bold))
                                    .foregroundColor(DUTheme.blue)
                            )
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            isSelected
                                ? LinearGradient(
                                    colors: [Color(hex: 0xFF6D77), Color(hex: 0xFF8F68)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing),
                            lineWidth: isSelected ? 2 : 0
                        )
                )

                Text(title)
                    .font(.du(11, weight: isSelected || isMoreTile ? .bold : .medium))
                    .foregroundColor(
                        isSelected
                            ? Color(hex: 0xFF4D61)
                            : DUTheme.inkSecondary
                    )
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .buttonStyle(.plain)
    }
}
