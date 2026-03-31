import AVKit
import SwiftUI

struct VideoHomeView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore

    @ObservedObject var viewModel: VideoViewModel

    @State private var isSearchPresented = false
    @State private var selectedVideoID: String?
    @State private var selectedCarouselIndex = 0

    private let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            switch viewModel.screenState {
            case .idle, .loading:
                loadingView
            case .featureDisabled:
                DUFeaturePlaceholderView(
                    title: .key("home.tab.video"),
                    icon: "🎬",
                    message: .key("home.feature.video.message")
                )
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
        }
        .fullScreenCover(isPresented: $isSearchPresented) {
            NavigationView {
                VideoSearchOverlayView(viewModel: viewModel) { videoID in
                    selectedVideoID = videoID
                }
            }
            .navigationViewStyle(.stack)
        }
        .duBottomSheet(
            isPresented: Binding(
                get: { viewModel.unavailablePresentation != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.dismissUnavailablePresentation()
                    }
                }
            ),
            preferredHeight: 420
        ) {
            if let presentation = viewModel.unavailablePresentation {
                VideoUnavailableSheet(
                    presentation: presentation,
                    onSelect: { videoID in
                        viewModel.dismissUnavailablePresentation()
                        selectedVideoID = videoID
                    },
                    onDismiss: {
                        viewModel.dismissUnavailablePresentation()
                    }
                )
            }
        }
        .overlay(alignment: .top) {
            if let toastMessage = viewModel.toastMessage {
                VideoToastBanner(message: localized(toastMessage))
                    .padding(.top, 16)
                    .padding(.horizontal, DUSpacing.lg)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .overlay(detailNavigationLink)
        .onReceive(timer) { _ in
            guard viewModel.carouselItems.count > 1 else {
                return
            }

            withAnimation(.easeInOut(duration: 0.35)) {
                selectedCarouselIndex = (selectedCarouselIndex + 1) % viewModel.carouselItems.count
            }
        }
        .onChange(of: viewModel.currentCategoryID) { _ in
            selectedCarouselIndex = 0
        }
        .onChange(of: viewModel.carouselItems.count) { _ in
            selectedCarouselIndex = 0
        }
    }

    private var loadingView: some View {
        VStack(spacing: DUSpacing.lg) {
            ProgressView()
                .tint(DUTheme.cyan)

            Text(localized("video.state.loading.title"))
                .font(.du(15, weight: .semibold))
                .foregroundColor(DUTheme.inkSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: LocalizedTextValue) -> some View {
        DUStateView(
            systemImage: "wifi.exclamationmark",
            iconColor: DUTheme.warning,
            title: localized("video.state.error.title"),
            subtitle: localized(message),
            actionTitle: localized("common.retry"),
            actionStyle: .secondary
        ) {
            Task {
                await viewModel.reload()
            }
        }
    }

    private var contentView: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                header(topInset: proxy.safeAreaInsets.top)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: DUSpacing.lg) {
                        carouselSection(containerWidth: proxy.size.width)
                        feedSection
                    }
                    .padding(.top, DUSpacing.md)
                    .padding(.bottom, DUSpacing.xxl)
                }
                .refreshable {
                    await viewModel.refresh()
                }
            }
            .background(DUTheme.background.ignoresSafeArea())
            .ignoresSafeArea(edges: .top)
        }
    }

    private func header(topInset: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.md) {
            Color.clear
                .frame(height: max(topInset, DUSpacing.md))

            Button {
                isSearchPresented = true
            } label: {
                HStack(spacing: DUSpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.du(15, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.88))

                    Text(localized("video.search.placeholder"))
                        .font(.du(13, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.78))
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, DUSpacing.md)
                .frame(height: 48)
                .background(Color.white.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DUSpacing.sm) {
                    ForEach(viewModel.navigation?.categories ?? []) { category in
                        Button {
                            Task {
                                await viewModel.selectCategory(id: category.id)
                            }
                        } label: {
                            VideoSelectionChip(
                                title: category.title.value(for: languageStore.currentLanguage),
                                isSelected: category.id == viewModel.currentCategoryID
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, DUSpacing.md)
        .padding(.bottom, DUSpacing.lg)
        .background(VideoTheme.headerGradient)
    }

    @ViewBuilder
    private func carouselSection(containerWidth: CGFloat) -> some View {
        if !viewModel.carouselItems.isEmpty {
            VStack(spacing: DUSpacing.md) {
                TabView(selection: $selectedCarouselIndex) {
                    ForEach(viewModel.carouselItems.indices, id: \.self) { index in
                        let item = viewModel.carouselItems[index]
                        Button {
                            Task {
                                await selectContent(item.content)
                            }
                        } label: {
                            ZStack(alignment: .bottomLeading) {
                                VideoImageView(
                                    image: item.content.backdropImage,
                                    cornerRadius: 28,
                                    contentMode: .fill
                                )
                                .overlay(
                                    LinearGradient(
                                        colors: [
                                            Color.black.opacity(0.06),
                                            Color.black.opacity(0.75),
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )

                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(hex: item.accentStartHex, opacity: 0.72),
                                                Color(hex: item.accentEndHex, opacity: 0.18),
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )

                                VStack(alignment: .leading, spacing: DUSpacing.sm) {
                                    Text(item.eyebrow.value(for: languageStore.currentLanguage))
                                        .font(.du(11, weight: .bold))
                                        .foregroundColor(.white.opacity(0.92))

                                    Text(item.content.title.value(for: languageStore.currentLanguage))
                                        .font(.du(24, weight: .bold))
                                        .foregroundColor(.white)
                                        .lineLimit(2)

                                    Text(item.content.summary.value(for: languageStore.currentLanguage))
                                        .font(.du(13, weight: .medium))
                                        .foregroundColor(.white.opacity(0.86))
                                        .lineLimit(2)

                                    HStack(spacing: DUSpacing.sm) {
                                        if let ratingText = item.content.ratingText {
                                            HStack(spacing: 4) {
                                                Image(systemName: "star.fill")
                                                    .font(.du(11, weight: .bold))
                                                Text(ratingText)
                                                    .font(.du(11, weight: .bold))
                                            }
                                            .foregroundColor(Color(hex: 0xFBBF24))
                                            .environment(\.layoutDirection, .leftToRight)
                                        }

                                        Text(item.content.metaLine.value(for: languageStore.currentLanguage))
                                            .font(.du(11, weight: .semibold))
                                            .foregroundColor(.white.opacity(0.8))
                                            .lineLimit(1)
                                    }
                                }
                                .padding(DUSpacing.lg)
                            }
                            .frame(height: 248)
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .tag(index)
                    }
                }
                .frame(height: 248)
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 6) {
                    ForEach(viewModel.carouselItems.indices, id: \.self) { index in
                        Capsule()
                            .fill(index == selectedCarouselIndex ? DUTheme.blue : DUTheme.line)
                            .frame(width: index == selectedCarouselIndex ? 22 : 8, height: 8)
                    }
                }
            }
            .padding(.horizontal, DUSpacing.md)
        }
    }

    private var feedSection: some View {
        VStack(alignment: .leading, spacing: DUSpacing.md) {
            if let feedSnapshot = viewModel.feedSnapshot {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: DUSpacing.md),
                        GridItem(.flexible(), spacing: DUSpacing.md),
                    ],
                    spacing: DUSpacing.md
                ) {
                    ForEach(feedSnapshot.items) { item in
                        VideoFeedCard(content: item) {
                            Task {
                                await selectContent(item)
                            }
                        }
                        .onAppear {
                            Task {
                                await viewModel.loadMoreIfNeeded(currentItem: item)
                            }
                        }
                    }
                }
                .padding(.horizontal, DUSpacing.md)

                loadMoreFooter
                    .padding(.horizontal, DUSpacing.md)
            }
        }
    }

    @ViewBuilder
    private var loadMoreFooter: some View {
        if viewModel.isLoadingMore {
            HStack(spacing: DUSpacing.sm) {
                ProgressView()
                    .tint(DUTheme.cyan)

                Text(localized("video.list.loadingMore"))
                    .font(.du(13, weight: .semibold))
                    .foregroundColor(DUTheme.inkSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DUSpacing.md)
        } else if let loadMoreError = viewModel.loadMoreError {
            DUStateView(
                systemImage: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90",
                iconColor: DUTheme.warning,
                title: localized("video.list.error.title"),
                subtitle: localized(loadMoreError)
            )
            .frame(height: 180)
        }
    }

    @ViewBuilder
    private var detailNavigationLink: some View {
        NavigationLink(
            destination: detailDestination,
            isActive: Binding(
                get: { selectedVideoID != nil },
                set: { isActive in
                    if !isActive {
                        selectedVideoID = nil
                    }
                }
            )
        ) {
            EmptyView()
        }
        .hidden()
    }

    @ViewBuilder
    private var detailDestination: some View {
        if let selectedVideoID {
            VideoDetailView(
                videoID: selectedVideoID,
                session: viewModel.session,
                videoService: viewModel.videoService
            )
        } else {
            EmptyView()
        }
    }

    private func localized(_ key: String, arguments: [String] = []) -> String {
        languageStore.string(key, arguments: arguments)
    }

    private func localized(_ value: LocalizedTextValue) -> String {
        languageStore.string(value)
    }

    private func selectContent(_ content: VideoContentSummary) async {
        if let videoID = await viewModel.handleSelection(of: content) {
            selectedVideoID = videoID
        }
    }
}

struct VideoSearchOverlayView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageStore: AppLanguageStore

    @ObservedObject var viewModel: VideoViewModel
    let onSelectVideo: (String) -> Void

    @State private var query = ""
    @State private var validationMessage: String?
    @State private var noResultKeyword: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .background(Color.white.ignoresSafeArea())
        .navigationBarHidden(true)
        .task {
            await viewModel.prepareSearchPanel()
        }
    }

    private var header: some View {
        VStack(spacing: DUSpacing.sm) {
            Color.clear.frame(height: 6)

            HStack(spacing: DUSpacing.md) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(.du(18, weight: .bold))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)

                HStack(spacing: DUSpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.du(14, weight: .semibold))
                        .foregroundColor(DUTheme.inkTertiary)

                    TextField(localized("video.search.placeholder"), text: $query)
                        .font(.du(13, weight: .medium))
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)

                    if !query.isEmpty {
                        Button {
                            query = ""
                            noResultKeyword = nil
                            validationMessage = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.du(14, weight: .semibold))
                                .foregroundColor(DUTheme.inkDisabled)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DUSpacing.md)
                .frame(height: 46)
                .background(Color.white.opacity(0.96))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                Button(localized("video.search.submit")) {
                    Task {
                        await submitSearch()
                    }
                }
                .font(.du(14, weight: .bold))
                .foregroundColor(.white)
                .buttonStyle(.plain)
            }

            if let validationMessage {
                Text(validationMessage)
                    .font(.du(12, weight: .semibold))
                    .foregroundColor(Color(hex: 0xFF4B5F))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, DUSpacing.md)
        .padding(.bottom, DUSpacing.md)
        .background(VideoTheme.headerGradient)
    }

    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: DUSpacing.md) {
                if let noResultKeyword {
                    DUStateView(
                        systemImage: "magnifyingglass",
                        iconColor: DUTheme.cyan,
                        title: localized("video.search.empty.title"),
                        subtitle: localized(
                            "video.search.empty.subtitle",
                            arguments: [noResultKeyword]
                        )
                    )
                    .frame(height: 220)
                    .padding(.horizontal, DUSpacing.md)
                }

                if !viewModel.mergedHistory.isEmpty {
                    historySection
                }
            }
            .padding(.vertical, DUSpacing.md)
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: DUSpacing.md) {
            HStack {
                Text(localized("video.search.history"))
                    .font(.du(16, weight: .bold))
                    .foregroundColor(DUTheme.ink)

                Spacer()

                Button(localized("video.search.clearAll")) {
                    Task {
                        await viewModel.clearHistory()
                        noResultKeyword = nil
                    }
                }
                .font(.du(12, weight: .semibold))
                .foregroundColor(DUTheme.inkTertiary)
                .buttonStyle(.plain)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 148), spacing: DUSpacing.sm)],
                spacing: DUSpacing.sm
            ) {
                ForEach(viewModel.mergedHistory, id: \.self) { keyword in
                    HStack(spacing: DUSpacing.sm) {
                        Button {
                            query = keyword
                            Task {
                                await submitSearch()
                            }
                        } label: {
                            Text(keyword)
                                .font(.du(12, weight: .medium))
                                .foregroundColor(DUTheme.inkSecondary)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Button {
                            Task {
                                await viewModel.deleteHistory(keyword: keyword)
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.du(14, weight: .semibold))
                                .foregroundColor(DUTheme.inkDisabled)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, DUSpacing.md)
                    .frame(height: 40)
                    .background(Color(hex: 0xF2F4F8))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(DUSpacing.lg)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 8)
        .padding(.horizontal, DUSpacing.md)
    }

    private func localized(_ key: String, arguments: [String] = []) -> String {
        languageStore.string(key, arguments: arguments)
    }

    private func submitSearch() async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty, trimmedQuery.count <= 50 else {
            validationMessage = localized("video.search.validation.empty")
            return
        }

        validationMessage = nil

        do {
            let response = try await viewModel.search(
                keyword: trimmedQuery,
                language: languageStore.currentLanguage
            )

            if let matchedContent = response.matchedContent {
                dismiss()
                onSelectVideo(matchedContent.id)
            } else {
                noResultKeyword = trimmedQuery
            }
        } catch let error as VideoServiceError {
            validationMessage = languageStore.string(error.textValue)
        } catch {
            validationMessage = localized("video.search.error.subtitle")
        }
    }
}

private struct VideoUnavailableSheet: View {
    @EnvironmentObject private var languageStore: AppLanguageStore

    let presentation: VideoUnavailablePresentation
    let onSelect: (String) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DUSpacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: DUSpacing.xs) {
                    Text(localized(presentation.title))
                        .font(.du(20, weight: .bold))
                        .foregroundColor(DUTheme.ink)

                    Text(presentation.message.value(for: languageStore.currentLanguage))
                        .font(.du(13, weight: .medium))
                        .foregroundColor(DUTheme.inkSecondary)
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.du(14, weight: .bold))
                        .foregroundColor(DUTheme.inkSecondary)
                        .frame(width: 32, height: 32)
                        .background(DUTheme.backgroundSecondary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            Text(localized("video.unavailable.recommendations"))
                .font(.du(14, weight: .bold))
                .foregroundColor(DUTheme.ink)

            VStack(spacing: DUSpacing.sm) {
                ForEach(presentation.recommendations) { item in
                    Button {
                        onSelect(item.id)
                    } label: {
                        HStack(spacing: DUSpacing.md) {
                            VideoImageView(
                                image: item.posterImage,
                                cornerRadius: 16,
                                contentMode: .fill
                            )
                            .frame(width: 64, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.title.value(for: languageStore.currentLanguage))
                                    .font(.du(14, weight: .bold))
                                    .foregroundColor(DUTheme.ink)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .lineLimit(2)

                                Text(item.subtitle.value(for: languageStore.currentLanguage))
                                    .font(.du(12, weight: .medium))
                                    .foregroundColor(DUTheme.inkSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .lineLimit(2)
                            }

                            Image(systemName: "chevron.forward")
                                .font(.du(13, weight: .bold))
                                .foregroundColor(DUTheme.inkDisabled)
                        }
                        .padding(DUSpacing.md)
                        .background(Color(hex: 0xF7FAFD))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(DUSpacing.lg)
        .background(Color.white)
    }

    private func localized(_ value: LocalizedTextValue) -> String {
        languageStore.string(value)
    }

    private func localized(_ key: String, arguments: [String] = []) -> String {
        languageStore.string(key, arguments: arguments)
    }
}

struct VideoDetailView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore

    @StateObject private var viewModel: VideoDetailViewModel
    @State private var selectedEpisodeID: String?
    @State private var selectedRelatedVideoID: String?
    @State private var playbackSession: VideoPlaybackSession?

    init(
        videoID: String,
        session: CustSubInfo,
        videoService: any VideoServicing
    ) {
        _viewModel = StateObject(
            wrappedValue: VideoDetailViewModel(
                videoID: videoID,
                session: session,
                videoService: videoService
            )
        )
    }

    var body: some View {
        Group {
            switch viewModel.screenState {
            case .idle, .loading:
                loadingView
            case let .failed(message):
                errorView(message)
            case .loaded:
                detailContent
            }
        }
        .background(DUTheme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadIfNeeded()
        }
        .onChange(of: viewModel.detail?.defaultEpisodeID ?? "") { value in
            if selectedEpisodeID == nil {
                selectedEpisodeID = value
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let detail = viewModel.detail {
                playBar(for: detail)
            }
        }
        .overlay(relatedNavigationLink)
        .fullScreenCover(item: $playbackSession) { playbackSession in
            if let detail = viewModel.detail {
                VideoPlayerContainerView(
                    detail: detail,
                    initialSession: playbackSession,
                    session: viewModel.session,
                    videoService: viewModel.videoService
                )
            }
        }
        .overlay(alignment: .top) {
            if let bannerMessage = viewModel.bannerMessage {
                VideoToastBanner(message: localized(bannerMessage))
                    .padding(.top, 12)
                    .padding(.horizontal, DUSpacing.lg)
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: DUSpacing.lg) {
            ProgressView()
                .tint(DUTheme.cyan)

            Text(localized("video.detail.loading"))
                .font(.du(15, weight: .semibold))
                .foregroundColor(DUTheme.inkSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: LocalizedTextValue) -> some View {
        DUStateView(
            systemImage: "exclamationmark.triangle.fill",
            iconColor: DUTheme.warning,
            title: localized("video.detail.error.title"),
            subtitle: localized(message),
            actionTitle: localized("common.retry"),
            actionStyle: .secondary
        ) {
            Task {
                await viewModel.reload()
            }
        }
    }

    private var detailContent: some View {
        ScrollView(showsIndicators: false) {
            if let detail = viewModel.detail {
                VStack(alignment: .leading, spacing: DUSpacing.lg) {
                    heroSection(detail)
                    statSection(detail)
                    synopsisSection(detail)

                    if !detail.episodeGroups.isEmpty {
                        episodeSection(detail)
                    }

                    if !detail.cast.isEmpty {
                        castSection(detail)
                    }

                    relatedSection(detail)
                }
                .padding(.bottom, DUSpacing.xxl)
            }
        }
    }

    private func heroSection(_ detail: VideoDetailSnapshot) -> some View {
        ZStack(alignment: .bottomLeading) {
            VideoImageView(
                image: detail.heroImage,
                cornerRadius: 0,
                contentMode: .fill
            )
            .frame(height: 320)
            .overlay(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.08),
                        Color.black.opacity(0.82),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            HStack(alignment: .bottom, spacing: DUSpacing.md) {
                VideoImageView(
                    image: detail.content.posterImage,
                    cornerRadius: 18,
                    contentMode: .fill
                )
                .frame(width: 112, height: 152)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: DUSpacing.sm) {
                    Text(detail.content.title.value(for: languageStore.currentLanguage))
                        .font(.du(24, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)

                    Text(detail.content.subtitle.value(for: languageStore.currentLanguage))
                        .font(.du(13, weight: .medium))
                        .foregroundColor(.white.opacity(0.84))
                        .lineLimit(2)

                    HStack(spacing: DUSpacing.sm) {
                        if let ratingText = detail.content.ratingText {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.du(11, weight: .bold))
                                Text(ratingText)
                                    .font(.du(11, weight: .bold))
                            }
                            .foregroundColor(Color(hex: 0xFBBF24))
                            .environment(\.layoutDirection, .leftToRight)
                        }

                        Text(detail.content.metaLine.value(for: languageStore.currentLanguage))
                            .font(.du(11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(detail.tags) { tag in
                                VideoTagChip(
                                    title: tag.title.value(for: languageStore.currentLanguage),
                                    style: tag.style
                                )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, DUSpacing.md)
            .padding(.bottom, DUSpacing.lg)
        }
        .overlay(alignment: .topTrailing) {
            if !detail.isPlayable {
                Text(detail.content.availabilityMessage?.value(for: languageStore.currentLanguage) ?? localized("video.unavailable.removed.title"))
                    .font(.du(11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(Color.black.opacity(0.7))
                    .clipShape(Capsule())
                    .padding(.top, DUSpacing.md)
                    .padding(.horizontal, DUSpacing.md)
            }
        }
    }

    private func statSection(_ detail: VideoDetailSnapshot) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: DUSpacing.md),
                GridItem(.flexible(), spacing: DUSpacing.md),
            ],
            spacing: DUSpacing.md
        ) {
            ForEach(detail.stats) { stat in
                VStack(alignment: .leading, spacing: DUSpacing.sm) {
                    HStack(spacing: DUSpacing.sm) {
                        Image(systemName: stat.systemImage)
                            .font(.du(15, weight: .bold))
                            .foregroundColor(DUTheme.blue)

                        Text(localized(stat.titleKey))
                            .font(.du(12, weight: .bold))
                            .foregroundColor(DUTheme.inkSecondary)
                    }

                    Text(stat.value)
                        .font(.du(18, weight: .bold))
                        .foregroundColor(DUTheme.ink)
                        .environment(\.layoutDirection, .leftToRight)
                }
                .padding(DUSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: Color.black.opacity(0.05), radius: 14, x: 0, y: 8)
            }
        }
        .padding(.horizontal, DUSpacing.md)
    }

    private func synopsisSection(_ detail: VideoDetailSnapshot) -> some View {
        DUSectionCard(title: localized("video.detail.synopsis")) {
            Text(detail.synopsis.value(for: languageStore.currentLanguage))
                .font(.du(14, weight: .medium))
                .foregroundColor(DUTheme.inkSecondary)
                .lineSpacing(5)
        }
        .padding(.horizontal, DUSpacing.md)
    }

    private func episodeSection(_ detail: VideoDetailSnapshot) -> some View {
        DUSectionCard(title: localized("video.detail.episodes")) {
            VStack(alignment: .leading, spacing: DUSpacing.md) {
                ForEach(detail.episodeGroups) { group in
                    VStack(alignment: .leading, spacing: DUSpacing.sm) {
                        Text(group.title.value(for: languageStore.currentLanguage))
                            .font(.du(13, weight: .bold))
                            .foregroundColor(DUTheme.ink)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: DUSpacing.sm) {
                                ForEach(group.episodes) { episode in
                                    Button {
                                        selectedEpisodeID = episode.id
                                    } label: {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(episode.title.value(for: languageStore.currentLanguage))
                                                .font(.du(12, weight: .bold))
                                                .foregroundColor(
                                                    selectedEpisodeID == episode.id
                                                        ? .white
                                                        : DUTheme.ink
                                                )

                                            if let subtitle = episode.subtitle?.value(for: languageStore.currentLanguage) {
                                                Text(subtitle)
                                                    .font(.du(11, weight: .medium))
                                                    .foregroundColor(
                                                        selectedEpisodeID == episode.id
                                                            ? Color.white.opacity(0.82)
                                                            : DUTheme.inkSecondary
                                                    )
                                                    .lineLimit(1)
                                            }
                                        }
                                        .padding(.horizontal, DUSpacing.md)
                                        .padding(.vertical, DUSpacing.md)
                                        .frame(width: 148, alignment: .leading)
                                        .background(
                                            selectedEpisodeID == episode.id
                                                ? DUTheme.brandGradient
                                                : LinearGradient(
                                                    colors: [Color(hex: 0xF7FAFD), Color.white],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, DUSpacing.md)
    }

    private func castSection(_ detail: VideoDetailSnapshot) -> some View {
        DUSectionCard(title: localized("video.detail.cast")) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DUSpacing.md) {
                    ForEach(detail.cast) { member in
                        VStack(alignment: .leading, spacing: DUSpacing.sm) {
                            if let avatarImage = member.avatarImage {
                                VideoImageView(
                                    image: avatarImage,
                                    cornerRadius: 20,
                                    contentMode: .fill
                                )
                                .frame(width: 116, height: 130)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            }

                            Text(member.name)
                                .font(.du(14, weight: .bold))
                                .foregroundColor(DUTheme.ink)
                                .lineLimit(1)

                            Text(member.role?.value(for: languageStore.currentLanguage) ?? "")
                                .font(.du(12, weight: .medium))
                                .foregroundColor(DUTheme.inkSecondary)
                                .lineLimit(1)
                        }
                        .frame(width: 116, alignment: .leading)
                    }
                }
            }
        }
        .padding(.horizontal, DUSpacing.md)
    }

    private func relatedSection(_ detail: VideoDetailSnapshot) -> some View {
        DUSectionCard(title: localized("video.detail.related")) {
            VStack(spacing: DUSpacing.sm) {
                ForEach(detail.related) { item in
                    Button {
                        selectedRelatedVideoID = item.id
                    } label: {
                        HStack(spacing: DUSpacing.md) {
                            VideoImageView(
                                image: item.posterImage,
                                cornerRadius: 18,
                                contentMode: .fill
                            )
                            .frame(width: 74, height: 92)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.title.value(for: languageStore.currentLanguage))
                                    .font(.du(14, weight: .bold))
                                    .foregroundColor(DUTheme.ink)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .lineLimit(2)

                                Text(item.summary.value(for: languageStore.currentLanguage))
                                    .font(.du(12, weight: .medium))
                                    .foregroundColor(DUTheme.inkSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .lineLimit(2)
                            }

                            Image(systemName: "chevron.forward")
                                .font(.du(13, weight: .bold))
                                .foregroundColor(DUTheme.inkDisabled)
                        }
                        .padding(DUSpacing.md)
                        .background(Color(hex: 0xF7FAFD))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, DUSpacing.md)
    }

    private func playBar(for detail: VideoDetailSnapshot) -> some View {
        VStack(spacing: DUSpacing.sm) {
            if !detail.isPlayable {
                Text(detail.content.availabilityMessage?.value(for: languageStore.currentLanguage) ?? localized("video.unavailable.removed.title"))
                    .font(.du(12, weight: .semibold))
                    .foregroundColor(DUTheme.warning)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            DUButton(
                title: localized("video.detail.playNow"),
                style: detail.isPlayable ? .primary : .secondary,
                isLoading: viewModel.isRequestingPlayback,
                isEnabled: detail.isPlayable && selectedEpisode != nil
            ) {
                Task {
                    playbackSession = await viewModel.requestPlaybackSession(
                        episodeID: selectedEpisode?.id
                    )
                }
            }
        }
        .padding(.horizontal, DUSpacing.md)
        .padding(.top, DUSpacing.md)
        .padding(.bottom, DUSpacing.md)
        .background(Color.white.shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: -2))
    }

    @ViewBuilder
    private var relatedNavigationLink: some View {
        NavigationLink(
            destination: relatedDestination,
            isActive: Binding(
                get: { selectedRelatedVideoID != nil },
                set: { isActive in
                    if !isActive {
                        selectedRelatedVideoID = nil
                    }
                }
            )
        ) {
            EmptyView()
        }
        .hidden()
    }

    @ViewBuilder
    private var relatedDestination: some View {
        if let selectedRelatedVideoID {
            VideoDetailView(
                videoID: selectedRelatedVideoID,
                session: viewModel.session,
                videoService: viewModel.videoService
            )
        } else {
            EmptyView()
        }
    }

    private var selectedEpisode: VideoEpisode? {
        let selectedEpisodeID = selectedEpisodeID ?? viewModel.detail?.defaultEpisodeID
        return viewModel.detail?.episodeGroups
            .flatMap(\.episodes)
            .first { $0.id == selectedEpisodeID }
    }

    private func localized(_ key: String, arguments: [String] = []) -> String {
        languageStore.string(key, arguments: arguments)
    }

    private func localized(_ value: LocalizedTextValue) -> String {
        languageStore.string(value)
    }
}

private struct VideoPlayerContainerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageStore: AppLanguageStore

    let detail: VideoDetailSnapshot
    let session: CustSubInfo
    let videoService: any VideoServicing

    @State private var playbackSession: VideoPlaybackSession
    @State private var player = AVPlayer()
    @State private var selectedQuality: VideoQuality
    @State private var selectedSubtitleID: String
    @State private var selectedAudioTrackID: String
    @State private var isLoadingEpisode = false

    init(
        detail: VideoDetailSnapshot,
        initialSession: VideoPlaybackSession,
        session: CustSubInfo,
        videoService: any VideoServicing
    ) {
        self.detail = detail
        self.session = session
        self.videoService = videoService
        _playbackSession = State(initialValue: initialSession)
        _selectedQuality = State(initialValue: initialSession.videoSources.first?.quality ?? .auto)
        _selectedSubtitleID = State(initialValue: initialSession.subtitles.first?.id ?? "")
        _selectedAudioTrackID = State(initialValue: initialSession.audioTracks.first(where: \.isDefault)?.id ?? initialSession.audioTracks.first?.id ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            VideoPlayerSurface(
                player: player,
                pipEnabled: playbackSession.pipEnabled
            )
            .frame(height: 264)
            .background(.black)

            ScrollView(showsIndicators: false) {
                VStack(spacing: DUSpacing.lg) {
                    if detail.episodeGroups.flatMap(\.episodes).count > 1 {
                        episodeSelectorSection
                    }

                    playbackControlsSection
                }
                .padding(DUSpacing.md)
            }
            .background(DUTheme.background.ignoresSafeArea())
        }
        .background(Color.black.ignoresSafeArea())
        .task {
            configurePlayer(for: playbackSession, preferredQuality: selectedQuality)
        }
        .onChange(of: selectedQuality) { value in
            configurePlayer(for: playbackSession, preferredQuality: value)
        }
        .onDisappear {
            player.pause()
        }
    }

    private var header: some View {
        HStack(spacing: DUSpacing.md) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.du(16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(playbackSession.mediaTitle.value(for: languageStore.currentLanguage))
                    .font(.du(16, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(playbackSession.episode.title.value(for: languageStore.currentLanguage))
                    .font(.du(12, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, DUSpacing.md)
        .padding(.top, DUSpacing.md)
        .padding(.bottom, DUSpacing.md)
        .background(Color.black)
    }

    private var episodeSelectorSection: some View {
        DUSectionCard(title: localized("video.player.episodes")) {
            VStack(alignment: .leading, spacing: DUSpacing.md) {
                ForEach(detail.episodeGroups) { group in
                    VStack(alignment: .leading, spacing: DUSpacing.sm) {
                        Text(group.title.value(for: languageStore.currentLanguage))
                            .font(.du(13, weight: .bold))
                            .foregroundColor(DUTheme.ink)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: DUSpacing.sm) {
                                ForEach(group.episodes) { episode in
                                    Button {
                                        Task {
                                            await switchEpisode(to: episode)
                                        }
                                    } label: {
                                        VideoSelectionChip(
                                            title: episode.title.value(for: languageStore.currentLanguage),
                                            isSelected: episode.id == playbackSession.episode.id
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var playbackControlsSection: some View {
        DUSectionCard(title: localized("video.player.playback")) {
            VStack(spacing: DUSpacing.md) {
                controlMenuRow(
                    title: localized("video.player.quality"),
                    currentValue: selectedQuality.title(for: languageStore.currentLanguage)
                ) {
                    ForEach(availableQualities, id: \.self) { quality in
                        Button {
                            selectedQuality = quality
                        } label: {
                            labelWithCheck(
                                quality.title(for: languageStore.currentLanguage),
                                isSelected: quality == selectedQuality
                            )
                        }
                    }
                }

                controlMenuRow(
                    title: localized("video.player.subtitle"),
                    currentValue: currentSubtitle?.displayName.value(for: languageStore.currentLanguage) ?? "-"
                ) {
                    ForEach(playbackSession.subtitles) { subtitle in
                        Button {
                            selectedSubtitleID = subtitle.id
                        } label: {
                            labelWithCheck(
                                subtitle.displayName.value(for: languageStore.currentLanguage),
                                isSelected: subtitle.id == selectedSubtitleID
                            )
                        }
                    }
                }

                controlMenuRow(
                    title: localized("video.player.audio"),
                    currentValue: currentAudioTrack?.displayName.value(for: languageStore.currentLanguage) ?? "-"
                ) {
                    ForEach(playbackSession.audioTracks) { audioTrack in
                        Button {
                            selectedAudioTrackID = audioTrack.id
                        } label: {
                            labelWithCheck(
                                audioTrack.displayName.value(for: languageStore.currentLanguage),
                                isSelected: audioTrack.id == selectedAudioTrackID
                            )
                        }
                    }
                }

                if playbackSession.pipEnabled {
                    Text(localized("video.player.pipHint"))
                        .font(.du(12, weight: .medium))
                        .foregroundColor(DUTheme.inkSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if isLoadingEpisode {
                    HStack(spacing: DUSpacing.sm) {
                        ProgressView()
                            .tint(DUTheme.cyan)

                        Text(localized("video.player.loading"))
                            .font(.du(13, weight: .semibold))
                            .foregroundColor(DUTheme.inkSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var currentSubtitle: VideoSubtitleTrack? {
        playbackSession.subtitles.first { $0.id == selectedSubtitleID }
    }

    private var currentAudioTrack: VideoAudioTrack? {
        playbackSession.audioTracks.first { $0.id == selectedAudioTrackID }
    }

    private var availableQualities: [VideoQuality] {
        Array(Set(playbackSession.videoSources.map(\.quality))).sorted {
            $0.sortOrder < $1.sortOrder
        }
    }

    private func controlMenuRow<MenuContent: View>(
        title: String,
        currentValue: String,
        @ViewBuilder menuContent: () -> MenuContent
    ) -> some View {
        HStack {
            Text(title)
                .font(.du(13, weight: .bold))
                .foregroundColor(DUTheme.ink)

            Spacer()

            Menu {
                menuContent()
            } label: {
                HStack(spacing: DUSpacing.sm) {
                    Text(currentValue)
                        .font(.du(12, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.du(11, weight: .bold))
                }
                .foregroundColor(DUTheme.inkSecondary)
                .padding(.horizontal, DUSpacing.md)
                .frame(height: 36)
                .background(DUTheme.backgroundSecondary)
                .clipShape(Capsule())
            }
        }
    }

    private func labelWithCheck(
        _ title: String,
        isSelected: Bool
    ) -> some View {
        HStack {
            Text(title)
            if isSelected {
                Image(systemName: "checkmark")
            }
        }
    }

    private func configurePlayer(
        for session: VideoPlaybackSession,
        preferredQuality: VideoQuality
    ) {
        let selectedSource = session.videoSources.first { $0.quality == preferredQuality }
            ?? session.videoSources.sorted { $0.quality.sortOrder < $1.quality.sortOrder }.first

        guard let selectedSource else {
            return
        }

        let playerItem = AVPlayerItem(url: selectedSource.url)
        player.replaceCurrentItem(with: playerItem)
        player.play()
    }

    private func switchEpisode(to episode: VideoEpisode) async {
        guard episode.id != playbackSession.episode.id else {
            return
        }

        isLoadingEpisode = true
        defer {
            isLoadingEpisode = false
        }

        do {
            let nextSession = try await videoService.requestPlaybackSession(
                videoID: detail.content.id,
                episodeID: episode.id,
                preferredQuality: selectedQuality,
                session: session
            )

            playbackSession = nextSession
            selectedQuality = nextSession.videoSources.first?.quality ?? selectedQuality
            selectedSubtitleID = nextSession.subtitles.first?.id ?? selectedSubtitleID
            selectedAudioTrackID = nextSession.audioTracks.first(where: \.isDefault)?.id
                ?? nextSession.audioTracks.first?.id
                ?? selectedAudioTrackID
            configurePlayer(for: nextSession, preferredQuality: selectedQuality)
        } catch {
            // 切集失败时保留当前播放状态，避免把播放器留在空白页。
        }
    }

    private func localized(_ key: String, arguments: [String] = []) -> String {
        languageStore.string(key, arguments: arguments)
    }
}
