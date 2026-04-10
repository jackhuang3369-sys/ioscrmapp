import SwiftUI

private let mallCartBottomTabBarKey = "mall-cart"

struct MallCartView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    // 复用首页根容器的底部导航开关，购物车页需要以沉浸式子页形态独占屏幕。
    @EnvironmentObject private var homeChromeState: HomeChromeState
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: MallViewModel

    @State private var isManaging = false
    @State private var managedSelectionIDs: Set<String> = []
    @State private var activeNotice: MallCartNotice?
    @State private var activeProduct: MallProduct?
    @State private var activeCartSelectionContext: MallCartSelectionContext?
    @State private var draftSelectionValueIDs: Set<String> = []

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                // 给悬浮头部预留布局空间，避免列表首行被覆盖。
                content(bottomSafeInset: proxy.safeAreaInsets.bottom)
                    .padding(.top, MallCartLayout.headerReservedHeight)

                if case .loaded = viewModel.cartState,
                   let snapshot = viewModel.cartSnapshot,
                   !snapshot.items.isEmpty {
                    bottomBar(snapshot: snapshot, bottomSafeInset: proxy.safeAreaInsets.bottom)
                }

                header()
                    .frame(maxHeight: .infinity, alignment: .top)
                    .zIndex(1)
            }
            .background(Color(hex: 0xF9FAFD).ignoresSafeArea())
        }
        .navigationBarHidden(true)
        .overlay(navigationLinks)
        .duBottomSheet(
            isPresented: Binding(
                get: { activeCartSelectionContext != nil },
                set: { isPresented in
                    if !isPresented {
                        activeCartSelectionContext = nil
                        draftSelectionValueIDs.removeAll()
                    }
                }
            ),
            preferredHeight: 610,
            showsGrabber: false
        ) {
            if let context = activeCartSelectionContext {
                MallProductSelectionSheet(
                    snapshot: context.detailSnapshot,
                    selectedValueIDs: $draftSelectionValueIDs,
                    locale: languageStore.locale,
                    language: languageStore.currentLanguage,
                    onPreviewImage: { _ in },
                    onClose: {
                        activeCartSelectionContext = nil
                        draftSelectionValueIDs.removeAll()
                    },
                    onConfirm: confirmCartSelection
                )
                .environmentObject(languageStore)
            }
        }
        .task {
            // 首次进入时立即隐藏首页底部导航，避免导航动画期间闪现。
            await MainActor.run {
                homeChromeState.hideBottomTabBar(for: mallCartBottomTabBarKey)
            }
            await viewModel.loadCartIfNeeded()
        }
        .onAppear {
            Task { @MainActor in
                // 下一帧再覆盖一次，兜住父页面 onAppear 可能把底部导航重新打开的情况。
                await Task.yield()
                homeChromeState.hideBottomTabBar(for: mallCartBottomTabBarKey)
            }
        }
        .onDisappear {
            homeChromeState.showBottomTabBar(for: mallCartBottomTabBarKey)
        }
        .onChange(of: viewModel.cartSnapshot?.items.map(\.id) ?? []) { itemIDs in
            managedSelectionIDs.formIntersection(Set(itemIDs))
        }
        .alert(item: $activeNotice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text(languageStore.string("common.ok")))
            )
        }
    }

    private func header() -> some View {
        ZStack {
            Text(languageStore.string("mall.cart.title"))
                .font(.du(18, weight: .bold))
                .foregroundColor(Color(hex: 0x242939))

            HStack(spacing: DUSpacing.md) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.du(MallCartLayout.chromeButtonIconSize, weight: .bold))
                        .foregroundColor(Color(hex: 0x44526D))
                        .frame(
                            width: MallCartLayout.chromeButtonSize,
                            height: MallCartLayout.chromeButtonSize
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.92))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color(hex: 0xE3E8F1), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                if hasCartItems {
                    Button {
                        isManaging.toggle()
                        managedSelectionIDs.removeAll()
                    } label: {
                        Text(languageStore.string(isManaging ? "mall.cart.close" : "mall.cart.manage"))
                            .font(.du(14, weight: .semibold))
                            .foregroundColor(Color(hex: 0x0B63F6))
                            .padding(.horizontal, 12)
                            .frame(height: MallCartLayout.chromeButtonSize)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.94))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color(hex: 0xE3E8F1), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear
                        .frame(width: 76, height: MallCartLayout.chromeButtonSize)
                }
            }
        }
        .padding(.horizontal, DUSpacing.md)
        // 购物车页使用常规导航栏节奏，只保留紧凑的顶部留白。
        .padding(.top, MallCartLayout.headerTopSpacing)
        .padding(.bottom, DUSpacing.xs)
        .background(Color.white)
    }

    @ViewBuilder
    private func content(bottomSafeInset: CGFloat) -> some View {
        switch viewModel.cartState {
        case .idle, .loading:
            MallCartLoadingView()
        case let .failed(message):
            MallCartErrorView(
                title: languageStore.string("mall.cart.error.title"),
                message: languageStore.string(message),
                retryTitle: languageStore.string("common.retry")
            ) {
                Task {
                    await viewModel.refreshCart()
                }
            }
        case .loaded:
            if let snapshot = viewModel.cartSnapshot {
                if snapshot.items.isEmpty {
                    MallCartEmptyView(
                        title: languageStore.string("mall.cart.empty.title"),
                        subtitle: languageStore.string("mall.cart.empty.subtitle"),
                        buttonTitle: languageStore.string("mall.cart.continueShopping")
                    ) {
                        dismiss()
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 12) {
                            ForEach(snapshot.items) { item in
                                MallCartItemRow(
                                    item: item,
                                    language: languageStore.currentLanguage,
                                    locale: languageStore.locale,
                                    selectionLabel: languageStore.string("mall.cart.selectedLabel"),
                                    invalidLabel: languageStore.string("mall.cart.invalid"),
                                    isManaging: isManaging,
                                    isSelected: currentSelectionContains(itemID: item.id, snapshot: snapshot),
                                    onToggleSelection: {
                                        toggleSelection(for: item, snapshot: snapshot)
                                    },
                                    onOpenSelection: {
                                        openSelectionSheet(for: item)
                                    },
                                    onOpenProduct: {
                                        openProductDetail(for: item)
                                    },
                                    onDecrease: {
                                        updateQuantity(for: item, delta: -1)
                                    },
                                    onIncrease: {
                                        updateQuantity(for: item, delta: 1)
                                    }
                                )
                            }
                        }
                        .padding(.top, DUSpacing.md)
                        .padding(.bottom, bottomBarHeight(bottomSafeInset: bottomSafeInset) + DUSpacing.lg)
                    }
                }
            } else {
                EmptyView()
            }
        }
    }

    private var navigationLinks: some View {
        NavigationLink(
            destination: Group {
                if let activeProduct {
                    MallProductDetailView(
                        viewModel: viewModel,
                        product: activeProduct
                    )
                } else {
                    EmptyView()
                }
            },
            isActive: Binding(
                get: { activeProduct != nil },
                set: { isPresented in
                    if !isPresented {
                        activeProduct = nil
                    }
                }
            )
        ) {
            EmptyView()
        }
        .hidden()
    }

    private func bottomBar(
        snapshot: MallCartSnapshot,
        bottomSafeInset: CGFloat
    ) -> some View {
        let bottomActionBarMetrics = MallBottomActionBarLayout.metrics(
            buttonHeight: MallCartLayout.bottomActionBarButtonHeight,
            bottomSafeInset: bottomSafeInset
        )

        return VStack(spacing: 0) {
            Rectangle()
                .fill(Color.clear)
                .frame(height: 0)

            HStack(spacing: DUSpacing.md) {
                Button {
                    toggleSelectAll(snapshot: snapshot)
                } label: {
                    HStack(spacing: DUSpacing.sm) {
                        MallCartSelectionIndicator(isSelected: isSelectAllSelected(snapshot: snapshot))

                        Text(languageStore.string("mall.cart.selectAll"))
                            .font(.du(13, weight: .medium))
                            .foregroundColor(Color(hex: 0xADB2C8))
                    }
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                if isManaging {
                    Button {
                        deleteManagedSelection()
                    } label: {
                        Text("\(languageStore.string("mall.cart.delete")) (\(managedSelectionIDs.count))")
                            .font(.du(16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 146, height: 48)
                            .background(deleteButtonBackground)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(managedSelectionIDs.isEmpty)
                } else {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(languageStore.string("mall.cart.subtotal"))
                            .font(.du(11, weight: .medium))
                            .foregroundColor(Color(hex: 0x8A96AE))

                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(snapshot.formattedSubtotal(for: languageStore.locale))
                                .font(.du(22, weight: .bold))
                                .foregroundColor(Color(hex: 0xEB1745))

                            Text("AED")
                                .font(.du(11, weight: .bold))
                                .foregroundColor(Color(hex: 0xEB1745))
                        }
                        .environment(\.layoutDirection, .leftToRight)
                    }

                    Button {
                        checkout(snapshot: snapshot)
                    } label: {
                        Text(languageStore.string("mall.cart.checkout.button"))
                            .font(.du(16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 146, height: 48)
                            .background(checkoutButtonBackground(snapshot: snapshot))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(snapshot.selectedItems.isEmpty)
                }
            }
            .padding(.horizontal, DUSpacing.lg)
            .padding(.top, bottomActionBarMetrics.topPadding)
            .padding(.bottom, bottomActionBarMetrics.bottomPadding)
        }
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: -4)
        .offset(y: bottomActionBarMetrics.verticalOffset)
        .ignoresSafeArea(edges: .bottom)
    }

    private func currentSelectionContains(
        itemID: String,
        snapshot: MallCartSnapshot
    ) -> Bool {
        if isManaging {
            return managedSelectionIDs.contains(itemID)
        }
        return snapshot.selectedItems.contains { $0.id == itemID }
    }

    private func isSelectAllSelected(snapshot: MallCartSnapshot) -> Bool {
        if isManaging {
            let selectableIDs = Set(snapshot.selectableItemIDs)
            guard !selectableIDs.isEmpty else {
                return false
            }
            return selectableIDs.isSubset(of: managedSelectionIDs)
        }
        return snapshot.isAllSelected
    }

    private func toggleSelection(
        for item: MallCartItem,
        snapshot: MallCartSnapshot
    ) {
        guard item.isSelectable else {
            return
        }

        if isManaging {
            if managedSelectionIDs.contains(item.id) {
                managedSelectionIDs.remove(item.id)
            } else {
                managedSelectionIDs.insert(item.id)
            }
            return
        }

        Task {
            do {
                try await viewModel.updateCartSelection(
                    itemIDs: [item.id],
                    isSelected: !item.isSelected
                )
            } catch {
                presentCartError(error)
            }
        }
    }

    private func toggleSelectAll(snapshot: MallCartSnapshot) {
        let selectableIDs = snapshot.selectableItemIDs
        guard !selectableIDs.isEmpty else {
            return
        }

        if isManaging {
            if isSelectAllSelected(snapshot: snapshot) {
                managedSelectionIDs.removeAll()
            } else {
                managedSelectionIDs = Set(selectableIDs)
            }
            return
        }

        Task {
            do {
                try await viewModel.updateCartSelection(
                    itemIDs: selectableIDs,
                    isSelected: !snapshot.isAllSelected
                )
            } catch {
                presentCartError(error)
            }
        }
    }

    private func updateQuantity(for item: MallCartItem, delta: Int) {
        let nextQuantity = min(max(item.quantity + delta, 1), 99)
        guard nextQuantity != item.quantity else {
            return
        }

        Task {
            do {
                try await viewModel.updateCartQuantity(itemID: item.id, quantity: nextQuantity)
            } catch {
                presentCartError(error)
            }
        }
    }

    private func openProductDetail(for item: MallCartItem) {
        guard !isManaging else {
            return
        }

        Task {
            do {
                let entry = try await viewModel.fetchProductDetailEntry(productID: item.productID)
                await MainActor.run {
                    activeProduct = entry.product
                }
            } catch {
                await MainActor.run {
                    presentCartError(error)
                }
            }
        }
    }

    private func openSelectionSheet(for item: MallCartItem) {
        guard !isManaging else {
            return
        }

        Task {
            do {
                let entry = try await viewModel.fetchProductDetailEntry(productID: item.productID)
                let draftValueIDs = entry.snapshot.sku(id: item.skuID).map { Set($0.valueIDs) } ?? []

                await MainActor.run {
                    activeCartSelectionContext = MallCartSelectionContext(
                        item: item,
                        product: entry.product,
                        detailSnapshot: entry.snapshot
                    )
                    draftSelectionValueIDs = draftValueIDs
                }
            } catch {
                await MainActor.run {
                    presentCartError(error)
                }
            }
        }
    }

    private func confirmCartSelection() {
        guard
            let context = activeCartSelectionContext,
            let matchedSKU = context.detailSnapshot.currentSKU(for: draftSelectionValueIDs)
        else {
            return
        }

        Task {
            do {
                try await viewModel.updateCartItemSKU(
                    item: context.item,
                    detailSnapshot: context.detailSnapshot,
                    sku: matchedSKU
                )
                await MainActor.run {
                    activeCartSelectionContext = nil
                    draftSelectionValueIDs.removeAll()
                }
            } catch {
                await MainActor.run {
                    presentCartError(error)
                }
            }
        }
    }

    private func deleteManagedSelection() {
        guard !managedSelectionIDs.isEmpty else {
            return
        }

        let targetIDs = Array(managedSelectionIDs)
        Task {
            do {
                try await viewModel.deleteCartItems(itemIDs: targetIDs)
                managedSelectionIDs.removeAll()
            } catch {
                presentCartError(error)
            }
        }
    }

    private func checkout(snapshot: MallCartSnapshot) {
        let selectedIDs = snapshot.selectedItems.map(\.id)
        guard !selectedIDs.isEmpty else {
            return
        }

        Task {
            do {
                let preview = try await viewModel.prepareCartCheckout(itemIDs: selectedIDs)
                activeNotice = MallCartNotice(
                    title: preview.title.value(for: languageStore.currentLanguage),
                    message: "\(preview.message.value(for: languageStore.currentLanguage))\n\(preview.formattedSubtotal(for: languageStore.locale)) AED"
                )
            } catch {
                presentCartError(error)
            }
        }
    }

    private var deleteButtonBackground: LinearGradient {
        if managedSelectionIDs.isEmpty {
            return LinearGradient(
                colors: [Color(hex: 0xEB1745, opacity: 0.38), Color(hex: 0xF698B0, opacity: 0.55)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }

        return LinearGradient(
            colors: [Color(hex: 0xFF2A54), Color(hex: 0xEB1745)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func checkoutButtonBackground(snapshot: MallCartSnapshot) -> LinearGradient {
        if snapshot.selectedItems.isEmpty {
            return LinearGradient(
                colors: [Color(hex: 0xFFB7C8), Color(hex: 0xF09AB0)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }

        return LinearGradient(
            colors: [Color(hex: 0xFF6A86), Color(hex: 0xEB1745)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var hasCartItems: Bool {
        !(viewModel.cartSnapshot?.items.isEmpty ?? true)
    }

    private func bottomBarHeight(bottomSafeInset: CGFloat) -> CGFloat {
        MallBottomActionBarLayout.metrics(
            buttonHeight: MallCartLayout.bottomActionBarButtonHeight,
            bottomSafeInset: bottomSafeInset
        ).reservedHeight
    }

    private func presentCartError(_ error: Error) {
        let message: String

        if let serviceError = error as? MallServiceError {
            message = languageStore.string(serviceError.textValue)
        } else {
            message = languageStore.string("mall.cart.error.subtitle")
        }

        activeNotice = MallCartNotice(
            title: languageStore.string("mall.cart.error.title"),
            message: message
        )
    }
}

private enum MallCartLayout {
    // 购物车头部按钮尺寸与商品详情页保持一致，避免跨页面切换时视觉跳动。
    static let chromeButtonSize: CGFloat = 30.6
    static let chromeButtonIconSize: CGFloat = 14.4
    // 购物车页采用常规导航栏高度，不复用详情页的沉浸式偏移。
    static let headerTopSpacing: CGFloat = DUSpacing.sm
    // 头部与首条购物车内容之间的缓冲距离，避免布局显得过挤。
    static let headerBottomSpacing: CGFloat = 2
    // 购物车结算按钮主体高度，交给商城公共底栏布局计算实际占位。
    static let bottomActionBarButtonHeight: CGFloat = 48
    // 内容区需要为悬浮头部整体预留高度，而不是只预留按钮高度。
    static let headerReservedHeight: CGFloat = headerTopSpacing + chromeButtonSize + headerBottomSpacing
}

private struct MallCartItemRow: View {
    let item: MallCartItem
    let language: AppLanguage
    let locale: Locale
    let selectionLabel: String
    let invalidLabel: String
    let isManaging: Bool
    let isSelected: Bool
    let onToggleSelection: () -> Void
    let onOpenSelection: () -> Void
    let onOpenProduct: () -> Void
    let onDecrease: () -> Void
    let onIncrease: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: DUSpacing.md) {
            Button(action: onToggleSelection) {
                MallCartSelectionIndicator(
                    isSelected: isSelected,
                    isEnabled: item.isSelectable
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 34)
            .disabled(!item.isSelectable)

            Button(action: onOpenProduct) {
                MallImageView(
                    image: item.image,
                    cornerRadius: 16,
                    cropsBitmapToFill: true,
                    bitmapFillScale: 0.92
                )
                .frame(width: 96, height: 96)
                .background(Color(hex: 0xF7F9F8))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isManaging)

            VStack(alignment: .leading, spacing: 10) {
                Button(action: onOpenProduct) {
                    Text(item.title.value(for: language))
                        .font(.du(16, weight: .semibold))
                        .foregroundColor(Color(hex: 0x242939))
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .disabled(isManaging)

                Button(action: onOpenSelection) {
                    HStack(spacing: 4) {
                        Text(selectionLabel)
                            .font(.du(12, weight: .medium))
                            .foregroundColor(Color(hex: 0x6674BD))

                        Text(item.selectedSummary.value(for: language))
                            .font(.du(13, weight: .medium))
                            .foregroundColor(Color(hex: 0x242939))
                            .lineLimit(1)

                        Image(systemName: "chevron.right")
                            .font(.du(10, weight: .bold))
                            .foregroundColor(Color(hex: 0xB2B9C9))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .disabled(isManaging)

                if item.isInvalid {
                    Button(action: onOpenProduct) {
                        Text(item.invalidReason?.value(for: language) ?? invalidLabel)
                            .font(.du(11, weight: .semibold))
                            .foregroundColor(Color(hex: 0xD2484C))
                            .padding(.horizontal, 10)
                            .frame(height: 24)
                            .background(Color(hex: 0xFFF0F1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isManaging)
                } else if let saleLabel = item.saleLabel?.value(for: language) {
                    Button(action: onOpenProduct) {
                        HStack(alignment: .center, spacing: 8) {
                            Text(saleLabel)
                                .font(.du(11, weight: .medium))
                                .foregroundColor(Color(hex: 0xEB1745))
                                .padding(.horizontal, 6)
                                .frame(height: 20)
                                .background(Color(hex: 0xFFE8EE))
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                            Text(item.formattedPrice(for: locale))
                                .font(.du(18, weight: .bold))
                                .foregroundColor(Color(hex: 0xEB1745))

                            Text("AED")
                                .font(.du(11, weight: .medium))
                                .foregroundColor(Color(hex: 0xEB1745))
                        }
                        .environment(\.layoutDirection, .leftToRight)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .disabled(isManaging)
                }

                HStack(alignment: .center, spacing: DUSpacing.md) {
                    Button(action: onOpenProduct) {
                        Group {
                            if let saleEndsText = item.saleEndsText?.value(for: language), !saleEndsText.isEmpty {
                                Text(saleEndsText)
                                    .font(.du(11, weight: .medium))
                                    .foregroundColor(Color(hex: 0x98A0BA))
                                    .lineLimit(1)
                            } else {
                                Text(item.formattedPrice(for: locale))
                                    .font(.du(18, weight: .bold))
                                    .foregroundColor(Color(hex: 0xEB1745))
                                    .environment(\.layoutDirection, .leftToRight)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .disabled(isManaging)

                    Spacer(minLength: 0)

                    MallCartQuantityStepper(
                        quantity: item.quantity,
                        isEnabled: !item.isInvalid,
                        onDecrease: onDecrease,
                        onIncrease: onIncrease
                    )
                }
            }
        }
        .padding(.horizontal, DUSpacing.lg)
        .padding(.vertical, DUSpacing.lg)
        .background(Color.white)
        .opacity(item.isInvalid ? 0.7 : 1)
    }
}

private struct MallCartQuantityStepper: View {
    let quantity: Int
    let isEnabled: Bool
    let onDecrease: () -> Void
    let onIncrease: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            stepperButton(
                systemName: "minus",
                isDisabled: !isEnabled || quantity <= 1,
                action: onDecrease
            )

            Text("\(quantity)")
                .font(.du(15, weight: .medium))
                .foregroundColor(Color(hex: 0x242939))
                .frame(minWidth: 12)

            stepperButton(
                systemName: "plus",
                isDisabled: !isEnabled,
                action: onIncrease
            )
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    private func stepperButton(
        systemName: String,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.du(13, weight: .bold))
                .foregroundColor(isDisabled ? Color(hex: 0xCDD3DF) : Color(hex: 0x44526D))
                .frame(width: 30, height: 30)
                .background(Color(hex: 0xF2F4F8))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

private struct MallCartSelectionIndicator: View {
    let isSelected: Bool
    var isEnabled = true

    var body: some View {
        Circle()
            .fill(circleFill)
            .frame(width: 24, height: 24)
            .overlay {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.du(12, weight: .bold))
                        .foregroundColor(.white)
                }
            }
    }

    private var circleFill: Color {
        guard isEnabled else {
            return Color(hex: 0xE6EBF2)
        }
        return isSelected ? Color(hex: 0xF31D4B) : Color(hex: 0xE1E7EF)
    }
}

private struct MallCartLoadingView: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in
                    HStack(alignment: .top, spacing: DUSpacing.md) {
                        Circle()
                            .fill(Color(hex: 0xE8EDF4))
                            .frame(width: 24, height: 24)
                            .padding(.top, 34)

                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(hex: 0xEEF2F7))
                            .frame(width: 96, height: 96)

                        VStack(alignment: .leading, spacing: 10) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color(hex: 0xEEF2F7))
                                .frame(height: 18)

                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color(hex: 0xF2F5F9))
                                .frame(width: 140, height: 14)

                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color(hex: 0xF4F6FA))
                                .frame(width: 112, height: 18)

                            HStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color(hex: 0xF2F5F9))
                                    .frame(width: 160, height: 12)
                                Spacer()
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color(hex: 0xF2F5F9))
                                    .frame(width: 92, height: 30)
                            }
                        }
                    }
                    .padding(.horizontal, DUSpacing.lg)
                    .padding(.vertical, DUSpacing.lg)
                    .background(Color.white)
                }
            }
            .padding(.top, DUSpacing.md)
        }
        .background(Color(hex: 0xF9FAFD))
    }
}

private struct MallCartEmptyView: View {
    let title: String
    let subtitle: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: DUSpacing.lg) {
            Spacer(minLength: 0)

            Image(systemName: "cart")
                .font(.du(34, weight: .semibold))
                .foregroundColor(Color(hex: 0xCAD3DE))

            VStack(spacing: DUSpacing.sm) {
                Text(title)
                    .font(.du(18, weight: .bold))
                    .foregroundColor(Color(hex: 0x242939))

                Text(subtitle)
                    .font(.du(13, weight: .medium))
                    .foregroundColor(Color(hex: 0x8592A8))
                    .multilineTextAlignment(.center)
            }

            Button(action: action) {
                Text(buttonTitle)
                    .font(.du(14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .frame(height: 44)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: 0xFF6A86), Color(hex: 0xEB1745)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, DUSpacing.xxxl)
    }
}

private struct MallCartErrorView: View {
    let title: String
    let message: String
    let retryTitle: String
    let retry: () -> Void

    var body: some View {
        DUStateView(
            systemImage: "wifi.exclamationmark",
            iconColor: DUTheme.magenta,
            title: title,
            subtitle: message,
            actionTitle: retryTitle,
            action: retry
        )
    }
}

private struct MallCartNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct MallCartSelectionContext {
    let item: MallCartItem
    let product: MallProduct
    let detailSnapshot: MallProductDetailSnapshot
}
