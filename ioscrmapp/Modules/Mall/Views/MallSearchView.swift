import SwiftUI

struct MallSearchView: View {
    @Environment(\.duTheme) private var theme
    @EnvironmentObject private var languageStore: AppLanguageStore
    @Environment(\.presentationMode) private var presentationMode

    @ObservedObject var viewModel: MallViewModel

    @State private var query = ""
    @State private var validationMessage: String?
    @State private var submittedQuery = ""
    @State private var isResultsPresented = false

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .background(MallPalette(theme: theme).panelBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .overlay(resultLink)
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    private var header: some View {
        return VStack(spacing: DUSpacing.sm) {
            Color.clear.frame(height: 4)

            MallSearchBarView(
                text: $query,
                placeholder: languageStore.string("mall.search.placeholder.page"),
                submitTitle: languageStore.string("mall.search.submit"),
                onBack: {
                    presentationMode.wrappedValue.dismiss()
                },
                onSubmit: {
                    runSearch(query)
                }
            )

            if let validationMessage {
                Text(validationMessage)
                    .font(.du(.metaStrong))
                    .foregroundColor(theme.colors.status.error)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, DUSpacing.md)
        .padding(.bottom, DUSpacing.md)
        .background(theme.colors.gradient.brand)
    }

    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: DUSpacing.md) {
                // 搜索历史只在有内容时展示，避免首次进入搜索页时出现空白卡片。
                if !(viewModel.searchBootstrap?.history ?? []).isEmpty {
                    historySection
                }
                hotKeywordSection
            }
            .padding(.vertical, DUSpacing.md)
        }
    }

    private var historySection: some View {
        let palette = MallPalette(theme: theme)

        return VStack(alignment: .leading, spacing: DUSpacing.md) {
            HStack {
                Text(languageStore.string("mall.search.history"))
                    .font(.du(.bodyLargeStrong))
                    .foregroundColor(palette.primaryText)

                Spacer()

                Button(languageStore.string("mall.search.clearAll")) {
                    Task {
                        await viewModel.clearHistory()
                    }
                }
                .font(.du(.metaStrong))
                .foregroundColor(palette.tertiaryText)
                .buttonStyle(.plain)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150), spacing: DUSpacing.sm)],
                spacing: DUSpacing.sm
            ) {
                ForEach(viewModel.searchBootstrap?.history ?? [], id: \.self) { keyword in
                    HStack(spacing: DUSpacing.sm) {
                        Button {
                            runSearch(keyword)
                        } label: {
                            HStack(spacing: 0) {
                                Text(keyword)
                                    .font(.du(.meta))
                                    .foregroundColor(palette.secondaryText)
                                    .lineLimit(1)

                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .buttonStyle(.plain)

                        Button {
                            Task {
                                await viewModel.deleteHistory(keyword: keyword)
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.du(.bodyStrong))
                                .foregroundColor(palette.disabledText)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, DUSpacing.md)
                    .frame(height: 40)
                    .background(palette.chipBackground)
                    .clipShape(Capsule())
                }
            }
        }
        .padding(DUSpacing.lg)
        .background(palette.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: DURadius.cardLarge, style: .continuous))
        .shadow(color: palette.cardElevation.color, radius: palette.cardElevation.radius, x: palette.cardElevation.x, y: palette.cardElevation.y)
        .padding(.horizontal, DUSpacing.md)
    }

    private var hotKeywordSection: some View {
        let palette = MallPalette(theme: theme)

        return VStack(alignment: .leading, spacing: DUSpacing.md) {
            Text(languageStore.string("mall.search.hot"))
                .font(.du(.bodyLargeStrong))
                .foregroundColor(palette.primaryText)

            VStack(spacing: DUSpacing.sm) {
                let hotKeywords = viewModel.searchBootstrap?.hotKeywords ?? []
                ForEach(hotKeywords.indices, id: \.self) { index in
                    let item = hotKeywords[index]

                    // 热搜词点击后直接复用统一搜索入口，保证校验和跳转行为一致。
                    Button {
                        runSearch(item.title.value(for: languageStore.currentLanguage))
                    } label: {
                        HStack(spacing: DUSpacing.md) {
                            Text("\(index + 1)")
                                .font(.du(.bodyEmphasized))
                                .foregroundColor(index < 3 ? theme.colors.status.error : palette.disabledText)
                                .frame(width: 18)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title.value(for: languageStore.currentLanguage))
                                    .font(.du(.labelStrong))
                                    .foregroundColor(palette.primaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Text(item.meta.value(for: languageStore.currentLanguage))
                                    .font(.du(.caption))
                                    .foregroundColor(palette.disabledText)
                            }
                        }
                        .padding(DUSpacing.md)
                        .background(palette.raisedBackground)
                        .clipShape(RoundedRectangle(cornerRadius: DURadius.control, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(DUSpacing.lg)
        .background(palette.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: DURadius.cardLarge, style: .continuous))
        .shadow(color: palette.cardElevation.color, radius: palette.cardElevation.radius, x: palette.cardElevation.x, y: palette.cardElevation.y)
        .padding(.horizontal, DUSpacing.md)
    }

    private var resultLink: some View {
        // 搜索页本身不直接承载结果列表，而是通过隐藏跳转复用结果页。
        NavigationLink(
            destination: MallSearchResultView(
                viewModel: viewModel,
                initialQuery: submittedQuery,
                initialCategoryID: nil
            ),
            isActive: $isResultsPresented
        ) {
            EmptyView()
        }
        .hidden()
    }

    private func runSearch(_ rawQuery: String) {
        let trimmedQuery = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        // 搜索词长度和空值校验统一放在入口，避免历史词、热搜词和手输走出不同分支。
        guard !trimmedQuery.isEmpty, trimmedQuery.count <= 50 else {
            validationMessage = languageStore.string("mall.search.validation.empty")
            return
        }

        validationMessage = nil
        query = trimmedQuery
        submittedQuery = trimmedQuery
        isResultsPresented = true
    }
}
