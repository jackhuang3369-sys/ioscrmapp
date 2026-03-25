import SwiftUI

struct MallCategoryView: View {
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
                        .font(.du(15, weight: .semibold))
                        .foregroundColor(DUTheme.inkSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.white.ignoresSafeArea())
        .navigationBarHidden(true)
        .overlay(searchNavigationLink)
        .task {
            await viewModel.loadIfNeeded()
            syncSelection()
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 4)

            HStack {
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.du(18, weight: .bold))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(languageStore.string("mall.category.title"))
                    .font(.du(17, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Color.clear.frame(width: 18, height: 18)
            }
            .padding(.horizontal, DUSpacing.lg)
            .padding(.vertical, DUSpacing.md)
        }
        .background(MallTheme.headerGradient)
    }

    private var sidebar: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(viewModel.homeSnapshot?.primaryCategories ?? []) { category in
                    Button {
                        selectedCategoryID = category.id
                        selectedSubcategoryID = ""
                    } label: {
                        HStack(spacing: 0) {
                            if category.id == selectedCategoryID {
                                RoundedRectangle(cornerRadius: 999, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: 0xFF6674), Color(hex: 0xFF8E68)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(width: 3, height: 36)
                            } else {
                                Color.clear.frame(width: 3, height: 36)
                            }

                            Text(category.title.value(for: languageStore.currentLanguage))
                                .font(.du(12, weight: category.id == selectedCategoryID ? .bold : .medium))
                                .foregroundColor(
                                    category.id == selectedCategoryID ? Color(hex: 0xFF4B5F) : DUTheme.inkSecondary
                                )
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DUSpacing.lg)
                                .background(category.id == selectedCategoryID ? Color.white : Color.clear)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(width: 88)
        .background(Color(hex: 0xF8FAFD))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(DUTheme.lineLight)
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
        Text(title)
            .font(.du(12, weight: isSelected ? .bold : .medium))
            .foregroundColor(isSelected ? Color(hex: 0xFF4D61) : DUTheme.inkSecondary)
            .padding(.horizontal, DUSpacing.md)
            .frame(height: 34)
            .background(isSelected ? Color(hex: 0xFFF2F3) : Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(
                        isSelected ? Color(hex: 0xFFB8C2) : DUTheme.lineLight,
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
