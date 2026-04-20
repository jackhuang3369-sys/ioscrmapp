import SwiftUI

struct MallCategoryView: View {
    @Environment(\.duTheme) private var theme
    @EnvironmentObject private var languageStore: AppLanguageStore
    @Environment(\.presentationMode) private var presentationMode

    @ObservedObject var viewModel: MallViewModel
    let initialCategoryID: String
    let initialSubcategoryID: String?

    @State private var selectedCategoryID = ""
    @State private var selectedSubcategoryID = ""
    @State private var searchResultRoute: MallCategorySearchRoute?

    var body: some View {
        Group {
            if let currentCategory {
                VStack(spacing: 0) {
                    header

                    HStack(spacing: 0) {
                        sidebar
                        categoryContent(for: currentCategory)
                    }
                }
            } else {
                VStack(spacing: DUSpacing.lg) {
                    ProgressView()
                    Text(languageStore.string("mall.state.loading.title"))
                        .font(.du(.bodyLargeSemibold))
                        .foregroundColor(MallPalette(theme: theme).secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(MallPalette(theme: theme).panelBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .overlay(searchNavigationLink)
        .task {
            await viewModel.loadIfNeeded()
            syncSelection()
        }
    }

    private var header: some View {
        let palette = MallPalette(theme: theme)

        return VStack(spacing: 0) {
            Color.clear.frame(height: 4)

            HStack {
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.du(.titleSmallStrong))
                        .foregroundColor(palette.inverseText)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(languageStore.string("mall.category.title"))
                    .font(.du(.titleSmall))
                    .foregroundColor(palette.inverseText)

                Spacer()

                Color.clear.frame(width: 18, height: 18)
            }
            .padding(.horizontal, DUSpacing.lg)
            .padding(.vertical, DUSpacing.md)
        }
        .background(theme.colors.gradient.brand)
    }

    private var sidebar: some View {
        let palette = MallPalette(theme: theme)

        return ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(viewModel.homeSnapshot?.primaryCategories ?? []) { category in
                    Button {
                        selectedCategoryID = category.id
                        selectedSubcategoryID = ""
                    } label: {
                        HStack(spacing: 0) {
                            if category.id == selectedCategoryID {
                                RoundedRectangle(cornerRadius: 999, style: .continuous)
                                    .fill(palette.badgeGradient(for: .sale))
                                    .frame(width: 3, height: 36)
                            } else {
                                Color.clear.frame(width: 3, height: 36)
                            }

                            Text(category.title.value(for: languageStore.currentLanguage))
                                .font(.du(category.id == selectedCategoryID ? .metaEmphasized : .meta))
                                .foregroundColor(
                                    category.id == selectedCategoryID ? theme.colors.status.error : palette.secondaryText
                                )
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DUSpacing.lg)
                                .background(category.id == selectedCategoryID ? palette.panelBackground : Color.clear)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(width: 88)
        .background(palette.canvasBackground)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(palette.subtleBorder)
                .frame(width: 1)
        }
    }

    private func categoryContent(for category: MallPrimaryCategory) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: DUSpacing.md) {
                subcategoryBar(for: category)

                VStack(alignment: .leading, spacing: DUSpacing.lg) {
                    ForEach(displayedSubcategories(for: category)) { subcategory in
                        MallCategorySectionCard(
                            title: subcategory.title.value(for: languageStore.currentLanguage),
                            items: subcategory.thirdCategories.map { item in
                                MallCategoryGridItem(
                                    id: "\(subcategory.id)-\(item.id)",
                                    title: item.title.value(for: languageStore.currentLanguage),
                                    image: item.image
                                )
                            }
                        ) { itemID in
                            guard let item = subcategory.thirdCategories.first(where: {
                                "\(subcategory.id)-\($0.id)" == itemID
                            }) else {
                                return
                            }

                            openSearchResult(
                                query: item.title.value(for: languageStore.currentLanguage),
                                categoryID: item.id
                            )
                        }
                    }
                }
                .padding(DUSpacing.lg)
                .duCardStyle()
            }
            .padding(DUSpacing.md)
        }
    }

    private func subcategoryBar(for category: MallPrimaryCategory) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DUSpacing.sm) {
                Button {
                    selectedSubcategoryID = ""
                } label: {
                    subcategoryChip(
                        title: allSubcategoryTitle,
                        isSelected: selectedSubcategoryID.isEmpty
                    )
                }
                .buttonStyle(.plain)

                ForEach(category.subcategories) { subcategory in
                    Button {
                        selectedSubcategoryID = subcategory.id
                    } label: {
                        subcategoryChip(
                            title: subcategory.title.value(for: languageStore.currentLanguage),
                            isSelected: subcategory.id == selectedSubcategoryID
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func subcategoryChip(
        title: String,
        isSelected: Bool
    ) -> some View {
        let palette = MallPalette(theme: theme)

        return Text(title)
            .font(.du(isSelected ? .metaEmphasized : .meta))
            .foregroundColor(isSelected ? theme.colors.status.error : palette.secondaryText)
            .padding(.horizontal, DUSpacing.md)
            .frame(height: 34)
            .background(isSelected ? palette.chipSelectedBackground : palette.panelBackground)
            .overlay(
                RoundedRectangle(cornerRadius: DURadius.control - 1, style: .continuous)
                    .stroke(
                        isSelected ? theme.colors.status.error.opacity(0.28) : palette.subtleBorder,
                        lineWidth: 1
                    )
            )
            .clipShape(Capsule())
    }

    private func displayedSubcategories(
        for category: MallPrimaryCategory
    ) -> [MallSubcategory] {
        if selectedSubcategoryID.isEmpty {
            return category.subcategories
        }

        return category.subcategories.filter { $0.id == selectedSubcategoryID }
    }

    private var searchNavigationLink: some View {
        NavigationLink(
            destination: searchResultDestination,
            isActive: searchResultPresentedBinding
        ) {
            EmptyView()
        }
        .hidden()
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

    private var currentCategory: MallPrimaryCategory? {
        viewModel.primaryCategory(id: selectedCategoryID)
    }

    private var allSubcategoryTitle: String {
        switch languageStore.currentLanguage {
        case .simplifiedChinese:
            return "全部"
        case .english:
            return "All"
        case .arabic:
            return "الكل"
        }
    }

    private func openSearchResult(
        query: String,
        categoryID: String?
    ) {
        searchResultRoute = MallCategorySearchRoute(
            query: query,
            categoryID: categoryID
        )
    }

    private func syncSelection() {
        let resolvedCategoryID = initialCategoryID.isEmpty
            ? viewModel.homeSnapshot?.defaultCategoryID ?? ""
            : initialCategoryID

        if selectedCategoryID.isEmpty {
            selectedCategoryID = resolvedCategoryID
        }

        if let category = viewModel.primaryCategory(id: selectedCategoryID) {
            let preferredSubcategoryID = selectedCategoryID == resolvedCategoryID
                ? initialSubcategoryID
                : nil

            let resolvedSubcategoryID = preferredSubcategoryID.flatMap { candidate in
                category.subcategories.contains(where: { $0.id == candidate }) ? candidate : nil
            }

            if let resolvedSubcategoryID {
                selectedSubcategoryID = resolvedSubcategoryID
            } else if !category.subcategories.contains(where: { $0.id == selectedSubcategoryID }) {
                selectedSubcategoryID = ""
            }
        }
    }
}

private struct MallCategorySearchRoute: Identifiable {
    let query: String
    let categoryID: String?

    var id: String {
        "\(query)-\(categoryID ?? "all")"
    }
}

private struct MallCategoryGridItem: Identifiable {
    let id: String
    let title: String
    let image: MallImageSource
}

private struct MallCategorySectionCard: View {
    let title: String
    let items: [MallCategoryGridItem]
    let action: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DUSpacing.md) {
            Text(title)
                .font(.du(15, weight: .bold))
                .foregroundColor(DUTheme.ink)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: DUSpacing.sm), count: 3),
                spacing: DUSpacing.lg
            ) {
                ForEach(items) { item in
                    Button {
                        action(item.id)
                    } label: {
                        VStack(spacing: DUSpacing.sm) {
                            MallImageView(
                                image: item.image,
                                cropsBitmapToFill: true,
                                bitmapFillScale: 1.12
                            )
                                .frame(maxWidth: .infinity)
                                .frame(height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                            Text(item.title)
                                .font(.du(12, weight: .medium))
                                .foregroundColor(DUTheme.inkSecondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
