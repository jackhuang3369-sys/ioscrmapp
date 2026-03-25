import SwiftUI

struct MallSearchResultView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    @Environment(\.presentationMode) private var presentationMode

    @ObservedObject var viewModel: MallViewModel
    let initialQuery: String
    let initialCategoryID: String?

    @State private var query: String
    @State private var activeSort: MallSearchSortMode = .best
    @State private var salesOrder: MallSortOrder = .descending
    @State private var priceOrder: MallSortOrder = .ascending
    @State private var validationMessage: String?
    @State private var resultSnapshot: MallSearchResultSnapshot?
    @State private var screenState: ScreenState = .loading
    @State private var selectedProduct: MallProduct?

    init(
        viewModel: MallViewModel,
        initialQuery: String,
        initialCategoryID: String?
    ) {
        self.viewModel = viewModel
        self.initialQuery = initialQuery
        self.initialCategoryID = initialCategoryID
        _query = State(initialValue: initialQuery)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            sortBar
            resultContent
        }
        .background(Color.white.ignoresSafeArea())
        .navigationBarHidden(true)
        .task {
            if resultSnapshot == nil {
                await performSearch()
            }
        }
        .sheet(item: $selectedProduct) { product in
            MallProductTargetSheet(product: product)
        }
    }

    private var header: some View {
        VStack(spacing: DUSpacing.sm) {
            Color.clear.frame(height: 4)

            MallSearchBarView(
                text: $query,
                placeholder: languageStore.string("mall.search.placeholder.page"),
                submitTitle: languageStore.string("mall.search.submit"),
                onBack: {
                    presentationMode.wrappedValue.dismiss()
                },
                onSubmit: {
                    Task {
                        await performSearch()
                    }
                }
            )

            if let validationMessage {
                Text(validationMessage)
                    .font(.du(12, weight: .semibold))
                    .foregroundColor(Color(hex: 0xFF4B5F))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, DUSpacing.md)
        .padding(.bottom, DUSpacing.md)
        .background(MallTheme.headerGradient)
    }

    private var sortBar: some View {
        HStack(spacing: 0) {
            ForEach(
                [MallSearchSortMode.best, .sales, .price],
                id: \.self
            ) { sort in
                // 销量/价格支持二次点击切换升降序，综合排序只负责回到默认权重。
                Button {
                    selectSort(sort)
                } label: {
                    HStack(spacing: 4) {
                        Text(languageStore.string(sort.localizationKey))
                            .lineLimit(1)
                            .font(.du(14, weight: activeSort == sort ? .bold : .medium))

                        if sort == .sales || sort == .price {
                            MallSearchSortIndicatorView(
                                isActive: activeSort == sort,
                                order: sort == .sales ? salesOrder : priceOrder
                            )
                        }
                    }
                    .foregroundColor(activeSort == sort ? Color(hex: 0xFF445D) : DUTheme.inkSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.white)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DUTheme.lineLight)
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private var resultContent: some View {
        switch screenState {
        case .loading:
            VStack(spacing: DUSpacing.lg) {
                ProgressView()
                Text(languageStore.string("mall.state.loading.title"))
                    .font(.du(15, weight: .semibold))
                    .foregroundColor(DUTheme.inkSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .failed(message):
            DUStateView(
                systemImage: "wifi.exclamationmark",
                iconColor: DUTheme.magenta,
                title: languageStore.string("mall.search.error.title"),
                subtitle: languageStore.string(message),
                actionTitle: languageStore.string("common.retry")
            ) {
                Task {
                    await performSearch()
                }
            }
        case .loaded:
            if let products = resultSnapshot?.products, !products.isEmpty {
                ScrollView(showsIndicators: false) {
                    // 结果页沿用首页商品卡片样式，降低搜索结果和首页推荐之间的认知切换。
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: DUSpacing.md),
                            GridItem(.flexible(), spacing: DUSpacing.md),
                        ],
                        spacing: DUSpacing.md
                    ) {
                        ForEach(products.indices, id: \.self) { index in
                            MallProductCard(product: products[index]) {
                                selectedProduct = products[index]
                            }
                            .padding(.top, index.isMultiple(of: 2) ? 0 : DUSpacing.lg)
                        }
                    }
                    .padding(DUSpacing.md)
                    .padding(.bottom, DUSpacing.xxl)
                }
            } else {
                DUStateView(
                    systemImage: "shippingbox",
                    iconColor: DUTheme.cyan,
                    title: languageStore.string("mall.search.empty.title"),
                    subtitle: languageStore.string("mall.search.empty.subtitle"),
                    actionTitle: languageStore.string("common.retry")
                ) {
                    Task {
                        await performSearch()
                    }
                }
            }
        }
    }

    private var effectiveOrder: MallSortOrder {
        switch activeSort {
        case .sales:
            return salesOrder
        case .price:
            return priceOrder
        case .best, .newest:
            return .descending
        }
    }

    private func selectSort(_ sort: MallSearchSortMode) {
        if sort == .sales {
            if activeSort == .sales {
                salesOrder = salesOrder == .ascending ? .descending : .ascending
            } else {
                activeSort = .sales
                salesOrder = .descending
            }
        } else if sort == .price {
            if activeSort == .price {
                priceOrder = priceOrder == .ascending ? .descending : .ascending
            } else {
                activeSort = .price
                priceOrder = .ascending
            }
        } else {
            activeSort = sort
        }

        Task {
            await performSearch()
        }
    }

    private func performSearch() async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        // 结果页顶部搜索框支持再次发起搜索，但仍然沿用相同的关键词校验。
        guard !trimmedQuery.isEmpty, trimmedQuery.count <= 50 else {
            validationMessage = languageStore.string("mall.search.validation.empty")
            screenState = .loaded
            resultSnapshot = nil
            return
        }

        validationMessage = nil
        screenState = .loading

        do {
            // 结果页会带着初始分类 ID 继续搜索，用于承接首页分类入口和活动入口跳转。
            resultSnapshot = try await viewModel.searchProducts(
                query: trimmedQuery,
                categoryID: initialCategoryID,
                sort: activeSort,
                order: effectiveOrder,
                language: languageStore.currentLanguage
            )
            screenState = .loaded
        } catch let error as MallServiceError {
            screenState = .failed(error.textValue)
        } catch {
            screenState = .failed(MallServiceError.searchUnavailable.textValue)
        }
    }
}

private extension MallSearchResultView {
    enum ScreenState: Equatable {
        case loading
        case loaded
        case failed(LocalizedTextValue)
    }
}

private struct MallSearchSortIndicatorView: View {
    let isActive: Bool
    let order: MallSortOrder

    var body: some View {
        VStack(spacing: 1) {
            Image(systemName: "arrowtriangle.up.fill")
                .font(.system(size: 7, weight: .bold))
                .foregroundColor(upColor)

            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 7, weight: .bold))
                .foregroundColor(downColor)
        }
        .offset(y: 1)
    }

    private var upColor: Color {
        guard isActive else {
            return DUTheme.inkDisabled.opacity(0.75)
        }
        return order == .ascending ? Color(hex: 0xFF445D) : DUTheme.inkDisabled.opacity(0.75)
    }

    private var downColor: Color {
        guard isActive else {
            return DUTheme.inkDisabled.opacity(0.75)
        }
        return order == .descending ? Color(hex: 0xFF445D) : DUTheme.inkDisabled.opacity(0.75)
    }
}
