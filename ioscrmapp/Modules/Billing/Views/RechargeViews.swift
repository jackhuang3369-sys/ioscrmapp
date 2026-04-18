import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

private enum RechargeDateFilterField {
    case start
    case end
}

struct RechargeContainerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.duTheme) private var theme
    @EnvironmentObject private var languageStore: AppLanguageStore
    @StateObject private var viewModel: RechargeViewModel
    @State private var isDateFilterPresented = false
    @State private var draftStartDate = Date()
    @State private var draftEndDate = Date()
    @State private var expandedDateField: RechargeDateFilterField?
    private let session: CustSubInfo
    private let aiChatService: any AIChatServicing
    private let onAIChatNavigation: (AIChatNavigationTarget) -> Void

    init(
        session: CustSubInfo,
        rechargeService: any RechargeServicing,
        aiChatService: any AIChatServicing,
        onAIChatNavigation: @escaping (AIChatNavigationTarget) -> Void = { _ in }
    ) {
        self.session = session
        _viewModel = StateObject(
            wrappedValue: RechargeViewModel(session: session, rechargeService: rechargeService)
        )
        self.aiChatService = aiChatService
        self.onAIChatNavigation = onAIChatNavigation
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("", selection: $viewModel.selectedTab) {
                    ForEach(RechargeTab.allCases) { tab in
                        Text(localized(tab.titleKey)).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, DUSpacing.lg)
                .padding(.top, DUSpacing.md)
                .padding(.bottom, DUSpacing.sm)

                Group {
                    switch viewModel.selectedTab {
                    case .recharge:
                        rechargeContent
                    case .orders:
                        ordersContent
                    }
                }
                .background(theme.colors.background.canvas.ignoresSafeArea())
            }
            .background(orderDetailNavigationLink)
            .navigationTitle(localized("recharge.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(localized("common.cancel")) {
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .task {
            await viewModel.loadIfNeeded()
        }
        .task(id: viewModel.selectedTab) {
            if viewModel.selectedTab == .orders {
                await viewModel.loadOrdersIfNeeded()
            }
        }
        .sheet(isPresented: $viewModel.isConfirmPresented) {
            RechargeConfirmView(viewModel: viewModel)
        }
        .fullScreenCover(item: $viewModel.acceptedReceipt) { receipt in
            RechargeAcceptedView(
                receipt: receipt,
                serviceNumber: viewModel.serviceNumberText,
                onBackToOrders: {
                    viewModel.dismissAcceptedReceipt()
                },
                onSaveSnapshot: {
                    saveSnapshot(for: receipt)
                },
                onShare: {
                    shareReceipt(receipt)
                }
            )
        }
        .fullScreenCover(item: $viewModel.failureFeedback) { failure in
            RechargeFailureView(
                failure: failure,
                amountText: viewModel.amountText,
                chargeMethod: localized(viewModel.selectedPaymentMethod.titleKey),
                onRetry: {
                    viewModel.retrySubmission()
                },
                onBack: {
                    viewModel.dismissFailure()
                }
            )
        }
        .sheet(isPresented: $isDateFilterPresented) {
            rechargeDateFilterSheet
        }
        .alert(isPresented: Binding(
            get: { viewModel.toastMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.dismissToast()
                }
            }
        )) {
            Alert(
                title: Text(localized("recharge.toast.title")),
                message: Text(localized(viewModel.toastMessage)),
                dismissButton: .default(Text(localized("common.ok"))) {
                    viewModel.dismissToast()
                }
            )
        }
        .businessAIAssistant(
            session: session,
            aiChatService: aiChatService,
            onNavigate: handleAIChatNavigation(_:)
        )
    }

    private var orderDetailNavigationLink: some View {
        NavigationLink(
            destination: presentedOrderDetailDestination,
            isActive: Binding(
                get: { viewModel.selectedOrder != nil },
                set: { isActive in
                    if !isActive {
                        viewModel.dismissOrderDetail()
                    }
                }
            )
        ) {
            EmptyView()
        }
        .hidden()
    }

    @ViewBuilder
    private var presentedOrderDetailDestination: some View {
        if let selectedOrder = viewModel.selectedOrder {
            RechargeOrderDetailView(record: selectedOrder)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private var rechargeContent: some View {
        switch viewModel.entryState {
        case .idle, .loading:
            rechargeLoadingState
        case let .failed(message):
            rechargeErrorState(message: message) {
                Task { await viewModel.refreshEntry() }
            }
        case .loaded:
            ScrollView(showsIndicators: false) {
                VStack(spacing: DUSpacing.lg) {
                    rechargeHeaderTitle(localized("recharge.tab.recharge"))
                    rechargeHero
                    rechargeAmountSection
                    rechargePaymentMethodSection
                    DUButton(
                        title: localized("recharge.primary"),
                        style: .primary,
                        isEnabled: !viewModel.isContinueDisabled
                    ) {
                        viewModel.openConfirm()
                    }
                }
                .padding(DUSpacing.lg)
                .padding(.bottom, DUSpacing.xxxl)
            }
            .refreshable {
                await viewModel.refreshEntry()
            }
        }
    }

    @ViewBuilder
    private var ordersContent: some View {
        switch viewModel.ordersState {
        case .idle, .loading:
            rechargeLoadingState
        case let .failed(message):
            rechargeErrorState(message: message) {
                Task { await viewModel.refreshOrders() }
            }
        case .loaded:
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        VStack(spacing: DUSpacing.lg) {
                            rechargeHeaderTitle(localized("recharge.tab.orders"))

                            if let snapshot = viewModel.ordersSnapshot, snapshot.records.isEmpty {
                                rechargeEmptyState
                            } else {
                                ordersListSection
                            }
                        }
                        .padding(.horizontal, DUSpacing.lg)
                        .padding(.top, DUSpacing.lg)
                        .padding(.bottom, DUSpacing.xxxl)
                    } header: {
                        ordersStickyFilterBar
                    }
                }
            }
            .refreshable {
                await viewModel.refreshOrders()
            }
        }
    }

    private func rechargeHeaderTitle(_ title: String) -> some View {
        Text(title)
            .font(.du(24, weight: .bold))
            .foregroundColor(theme.colors.text.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rechargeHero: some View {
        VStack(alignment: .leading, spacing: DUSpacing.lg) {
            Text(localized("recharge.balance.title"))
                .font(.du(12, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))

            Text(viewModel.balanceText)
                .font(.du(30, weight: .bold))
                .foregroundColor(.white)

            rechargeHeroMetric(
                title: localized("recharge.hero.serviceNumber"),
                value: viewModel.serviceNumberText
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DUSpacing.xl)
        .background(theme.colors.gradient.brand)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func rechargeHeroMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.xs) {
            Text(title)
                .font(.du(10, weight: .medium))
                .foregroundColor(.white.opacity(0.72))
            Text(value)
                .font(.du(14, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DUSpacing.md)
        .background(Color.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var rechargeAmountSection: some View {
        DUSectionCard(title: localized("recharge.amount.title")) {
            VStack(alignment: .leading, spacing: DUSpacing.md) {
                HStack {
                    Text(localized("recharge.quick.title"))
                        .font(.du(13, weight: .semibold))
                        .foregroundColor(theme.colors.text.primary)
                    Spacer()
                    Text(localized("recharge.amount.minimum", arguments: [viewModel.minimumAmountDisplayText]))
                        .font(.du(12, weight: .medium))
                        .foregroundColor(theme.colors.text.tertiary)
                }

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: DUSpacing.sm),
                        GridItem(.flexible(), spacing: DUSpacing.sm)
                    ],
                    spacing: DUSpacing.sm
                ) {
                    ForEach(viewModel.quickAmounts, id: \.self) { amount in
                        let amountValue = BillingNumberParser.string(amount)
                        let isSelected = BillingNumberParser.normalized(viewModel.amountText) == BillingNumberParser.normalized(amountValue)

                        Button {
                            viewModel.applyQuickAmount(amount)
                        } label: {
                            Text(BillingNumberParser.displayMoney(NSDecimalNumber(decimal: amount).stringValue))
                                .font(.du(14, weight: .bold))
                                .foregroundColor(isSelected ? .white : theme.colors.text.primary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(quickAmountBackground(isSelected: isSelected))
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: DUSpacing.sm) {
                    HStack(spacing: DUSpacing.md) {
                        TextField(localized("recharge.amount.placeholder"), text: $viewModel.amountText)
                            .keyboardType(.decimalPad)
                            .font(.du(26, weight: .bold))
                            .foregroundColor(theme.colors.text.primary)
                            .onChange(of: viewModel.amountText) { _ in
                                viewModel.sanitizeAmountInput()
                            }

                        Text("AED")
                            .font(.du(15, weight: .bold))
                            .foregroundColor(viewModel.amountError == nil ? theme.colors.brand.primary : theme.colors.status.error)
                    }
                    .padding(.horizontal, DUSpacing.lg)
                    .frame(height: 64)
                    .background(theme.colors.background.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(viewModel.amountError == nil ? theme.colors.border.default : theme.colors.status.error, lineWidth: 1.2)
                    )

                    if let amountError = viewModel.amountError {
                        Text(amountError)
                            .font(.du(12, weight: .medium))
                            .foregroundColor(theme.colors.status.error)
                    }
                }
            }
        }
    }

    private var rechargePaymentMethodSection: some View {
        DUSectionCard(title: localized("recharge.method.title")) {
            VStack(alignment: .leading, spacing: DUSpacing.sm) {
                ForEach(RechargePaymentMethod.allCases) { method in
                    let isSelected = viewModel.selectedPaymentMethod == method

                    Button {
                        viewModel.selectedPaymentMethod = method
                    } label: {
                        HStack(spacing: DUSpacing.md) {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(paymentMethodAccent(method))
                                .frame(width: 46, height: 46)
                                .overlay {
                                    Image(systemName: paymentMethodIcon(method))
                                        .font(.du(18, weight: .bold))
                                        .foregroundColor(.white)
                                }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(localized(method.titleKey))
                                    .font(.du(15, weight: .semibold))
                                    .foregroundColor(theme.colors.text.primary)
                            }

                            Spacer()

                            Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                                .font(.du(18, weight: .bold))
                                .foregroundColor(isSelected ? theme.colors.brand.primary : theme.colors.text.disabled)
                        }
                        .padding(DUSpacing.lg)
                        .background(theme.colors.surface.card)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(isSelected ? theme.colors.brand.primary : theme.colors.border.subtle, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func paymentMethodIcon(_ method: RechargePaymentMethod) -> String {
        switch method {
        case .creditCard:
            return "creditcard.fill"
        case .applePay:
            return "apple.logo"
        case .bankTransfer:
            return "building.columns.fill"
        }
    }

    private func paymentMethodAccent(_ method: RechargePaymentMethod) -> Color {
        switch method {
        case .creditCard:
            return theme.colors.brand.primary
        case .applePay:
            return theme.colors.text.primary
        case .bankTransfer:
            return theme.colors.brand.secondary
        }
    }

    private var ordersStickyFilterBar: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: DUSpacing.md) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DUSpacing.sm) {
                        rechargeStatusFilterPill(
                            title: localized("recharge.orders.filter.all"),
                            isSelected: viewModel.orderFilter.status == nil
                        ) {
                            viewModel.orderFilter.status = nil
                            Task { await viewModel.refreshOrders() }
                        }

                        ForEach(RechargeOrderStatus.allCases) { status in
                            rechargeStatusFilterPill(
                                title: localized(status.titleKey),
                                isSelected: viewModel.orderFilter.status == status
                            ) {
                                viewModel.orderFilter.status = status
                                Task { await viewModel.refreshOrders() }
                            }
                        }
                    }
                }

                    Button {
                        draftStartDate = viewModel.orderFilter.startDate ?? Date()
                        draftEndDate = viewModel.orderFilter.endDate ?? Date()
                        expandedDateField = nil
                        isDateFilterPresented = true
                    } label: {
                    HStack(spacing: DUSpacing.xs) {
                        Image(systemName: "calendar")
                            .font(.du(12, weight: .bold))
                        Text(dateFilterButtonTitle)
                            .font(.du(12, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundColor(theme.colors.brand.primary)
                    .padding(.horizontal, DUSpacing.md)
                    .frame(height: 34)
                    .background(theme.colors.action.primaryBackground)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DUSpacing.lg)
            .padding(.vertical, DUSpacing.md)
            .background(theme.colors.background.canvas)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.colors.border.subtle)
                .frame(height: 1)
        }
    }

    private func rechargeStatusFilterPill(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.du(12, weight: .semibold))
                .foregroundColor(isSelected ? .white : theme.colors.text.primary)
                .padding(.horizontal, DUSpacing.md)
                .frame(height: 34)
                .background(statusFilterBackground(isSelected: isSelected))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var dateFilterButtonTitle: String {
        guard let startDate = viewModel.orderFilter.startDate,
              let endDate = viewModel.orderFilter.endDate else {
            return localized("recharge.orders.filter.date")
        }

        return "\(Self.filterDateFormatter.string(from: startDate))-\(Self.filterDateFormatter.string(from: endDate))"
    }

    private var rechargeDateFilterSheet: some View {
        NavigationView {
            VStack(spacing: DUSpacing.lg) {
                VStack(alignment: .leading, spacing: DUSpacing.md) {
                    Text(localized("recharge.orders.filter.date"))
                        .font(.du(15, weight: .bold))
                        .foregroundColor(theme.colors.text.primary)

                    HStack(spacing: DUSpacing.sm) {
                        dateValueButton(
                            title: Self.filterDateFormatter.string(from: draftStartDate),
                            isExpanded: expandedDateField == .start
                        ) {
                            expandedDateField = expandedDateField == .start ? nil : .start
                        }

                        Text("-")
                            .font(.du(16, weight: .bold))
                            .foregroundColor(theme.colors.text.secondary)

                        dateValueButton(
                            title: Self.filterDateFormatter.string(from: draftEndDate),
                            isExpanded: expandedDateField == .end
                        ) {
                            expandedDateField = expandedDateField == .end ? nil : .end
                        }
                    }

                    if let expandedDateField {
                        rechargeDatePickerCard(
                            title: expandedDateField == .start
                                ? localized("recharge.orders.filter.start")
                                : localized("recharge.orders.filter.end"),
                            selection: dateSelectionBinding(for: expandedDateField)
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DUSpacing.lg)
                .background(theme.colors.surface.card)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                HStack(spacing: DUSpacing.md) {
                    DUButton(title: localized("recharge.orders.filter.apply"), style: .primary, fontSize: 14) {
                        applyDateFilter()
                    }
                    DUButton(title: localized("recharge.orders.filter.clear"), style: .secondary, fontSize: 14) {
                        clearDateFilter()
                    }
                }

                Spacer()
            }
            .padding(DUSpacing.lg)
            .background(theme.colors.background.canvas.ignoresSafeArea())
            .navigationTitle(localized("recharge.orders.filter.date"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(localized("common.cancel")) {
                        isDateFilterPresented = false
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func dateValueButton(
        title: String,
        isExpanded: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: DUSpacing.xs) {
                Text(title)
                    .font(.du(15, weight: .semibold))
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.du(11, weight: .bold))
            }
            .foregroundColor(isExpanded ? .white : theme.colors.brand.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(isExpanded ? theme.colors.brand.primary : theme.colors.action.primaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func rechargeDatePickerCard(
        title: String,
        selection: Binding<Date>
    ) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.sm) {
            Text(title)
                .font(.du(13, weight: .semibold))
                .foregroundColor(theme.colors.text.secondary)

            RechargeNumericDatePicker(selection: selection)
        }
        .padding(DUSpacing.lg)
        .background(theme.colors.background.canvas)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func dateSelectionBinding(for field: RechargeDateFilterField) -> Binding<Date> {
        Binding(
            get: {
                field == .start ? draftStartDate : draftEndDate
            },
            set: { newValue in
                let normalizedDate = Calendar(identifier: .gregorian).startOfDay(for: newValue)
                switch field {
                case .start:
                    draftStartDate = normalizedDate
                    if draftStartDate > draftEndDate {
                        draftEndDate = draftStartDate
                    }
                case .end:
                    draftEndDate = normalizedDate
                    if draftEndDate < draftStartDate {
                        draftStartDate = draftEndDate
                    }
                }
            }
        )
    }

    private func applyDateFilter() {
        viewModel.orderFilter.startDate = draftStartDate
        viewModel.orderFilter.endDate = draftEndDate
        expandedDateField = nil
        isDateFilterPresented = false

        Task {
            await viewModel.refreshOrders()
        }
    }

    private func clearDateFilter() {
        viewModel.orderFilter.startDate = nil
        viewModel.orderFilter.endDate = nil
        expandedDateField = nil
        isDateFilterPresented = false

        Task {
            await viewModel.refreshOrders()
        }
    }

    @ViewBuilder
    private func quickAmountBackground(isSelected: Bool) -> some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.colors.gradient.brand)
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.colors.background.secondary)
        }
    }

    @ViewBuilder
    private func statusFilterBackground(isSelected: Bool) -> some View {
        if isSelected {
            Capsule()
                .fill(theme.colors.gradient.brand)
        } else {
            Capsule()
                .fill(theme.colors.background.secondary)
        }
    }

    private var ordersListSection: some View {
        LazyVStack(spacing: DUSpacing.md) {
            ForEach(viewModel.ordersSnapshot?.records ?? []) { record in
                rechargeOrderCard(record)
                    .onAppear {
                        guard record.id == viewModel.ordersSnapshot?.records.last?.id else {
                            return
                        }
                        Task {
                            await viewModel.loadMoreOrdersIfNeeded(currentRecord: record)
                        }
                    }
            }

            if viewModel.hasMoreOrders,
               let lastRecord = viewModel.ordersSnapshot?.records.last {
                Color.clear
                    .frame(height: 24)
                    .onAppear {
                        Task {
                            await viewModel.loadMoreOrdersIfNeeded(currentRecord: lastRecord)
                        }
                    }
            }

            if viewModel.isLoadingMoreOrders {
                HStack(spacing: DUSpacing.sm) {
                    ProgressView()
                    Text(localized("recharge.orders.loadingMore"))
                        .font(.du(12, weight: .medium))
                        .foregroundColor(theme.colors.text.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DUSpacing.md)
            }
        }
    }

    private func rechargeOrderCard(_ record: RechargeOrderRecord) -> some View {
        Button {
            viewModel.openOrderDetail(record)
        } label: {
            VStack(alignment: .leading, spacing: DUSpacing.md) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: DUSpacing.xs) {
                        Text("#\(record.orderId)")
                            .font(.du(15, weight: .bold))
                            .foregroundColor(theme.colors.text.primary)
                        Text(record.createdTimeText)
                            .font(.du(12, weight: .medium))
                            .foregroundColor(theme.colors.text.secondary)
                    }

                    Spacer()

                    Text(localized(record.status.titleKey))
                        .font(.du(12, weight: .bold))
                        .foregroundColor(statusTint(record.status))
                        .padding(.horizontal, DUSpacing.md)
                        .frame(height: 30)
                        .background(statusBackground(record.status))
                        .clipShape(Capsule())
                }

                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: DUSpacing.xs) {
                        Text(localized("recharge.receipt.chargeMethod"))
                            .font(.du(11, weight: .medium))
                            .foregroundColor(theme.colors.text.tertiary)
                        Text(record.chargeMethod)
                            .font(.du(14, weight: .semibold))
                            .foregroundColor(theme.colors.text.primary)
                    }

                    Spacer()

                    Text(record.amountText)
                        .font(.du(18, weight: .bold))
                        .foregroundColor(theme.colors.text.primary)
                }

                HStack {
                    if let failureMessageKey = record.failureMessageKey {
                        Text(localized(failureMessageKey))
                            .font(.du(12, weight: .medium))
                            .foregroundColor(theme.colors.status.error)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: DUSpacing.sm)

                    Image(systemName: "chevron.right")
                        .font(.du(12, weight: .bold))
                        .foregroundColor(theme.colors.text.tertiary)
                }
            }
            .padding(DUSpacing.lg)
            .background(theme.colors.background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var rechargeLoadingState: some View {
        VStack(spacing: DUSpacing.lg) {
            ProgressView()
            Text(localized("recharge.state.loading"))
                .font(.du(15, weight: .semibold))
                .foregroundColor(theme.colors.text.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.colors.background.canvas.ignoresSafeArea())
    }

    private func rechargeErrorState(
        message: LocalizedTextValue,
        retry: @escaping () -> Void
    ) -> some View {
        DUStateView(
            systemImage: "wifi.exclamationmark",
            iconColor: theme.colors.status.error,
            title: localized("recharge.state.errorTitle"),
            subtitle: localized(message),
            actionTitle: localized("common.retry"),
            footer: nil
        ) {
            retry()
        }
    }

    private var rechargeEmptyState: some View {
        DUStateView(
            systemImage: "clock.badge.exclamationmark",
            iconColor: theme.colors.brand.primary,
            title: localized("recharge.orders.empty.title"),
            subtitle: localized("recharge.orders.empty.subtitle"),
            actionTitle: localized("common.reload"),
            footer: nil
        ) {
            Task {
                await viewModel.refreshOrders()
            }
        }
    }

    private func statusTint(_ status: RechargeOrderStatus) -> Color {
        switch status {
        case .processing:
            return theme.colors.status.warning
        case .success:
            return theme.colors.status.success
        case .failed:
            return theme.colors.status.error
        }
    }

    private func statusBackground(_ status: RechargeOrderStatus) -> Color {
        switch status {
        case .processing:
            return theme.colors.status.warningBackground
        case .success:
            return theme.colors.status.successBackground
        case .failed:
            return theme.colors.status.errorBackground
        }
    }

    private func shareReceipt(_ receipt: RechargeAcceptedReceipt) {
        #if canImport(UIKit)
        let items = [receipt.orderId, receipt.amountText, receipt.requestChargeMethod]
        presentShareSheet(items: items)
        #endif
    }

    private func saveSnapshot(for receipt: RechargeAcceptedReceipt) {
        #if canImport(UIKit)
        if let image = RechargeSnapshotRenderer.makeImage(
            receipt: receipt,
            serviceNumber: viewModel.serviceNumberText,
            localizedTitle: localized("recharge.success.title")
        ) {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        }
        #endif
    }

    #if canImport(UIKit)
    private func presentShareSheet(items: [Any]) {
        guard !items.isEmpty,
              let presenter = RechargeSharePresenter.topViewController() else {
            return
        }

        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let popover = controller.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(
                x: presenter.view.bounds.midX,
                y: presenter.view.bounds.midY,
                width: 1,
                height: 1
            )
        }
        presenter.present(controller, animated: true)
    }
    #endif

    private func localized(_ key: String, arguments: [String] = []) -> String {
        languageStore.string(key, arguments: arguments)
    }

    private func localized(_ value: LocalizedTextValue?) -> String {
        languageStore.string(value)
    }

    private func handleAIChatNavigation(_ target: AIChatNavigationTarget) {
        guard shouldForwardAIChatNavigation(target) else {
            return
        }

        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onAIChatNavigation(target)
        }
    }

    private func shouldForwardAIChatNavigation(_ target: AIChatNavigationTarget) -> Bool {
        switch target {
        case .recharge, .external:
            return false
        default:
            return true
        }
    }

    private static let filterDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter
    }()
}

#if canImport(UIKit)
private enum RechargeSharePresenter {
    static func topViewController(
        from controller: UIViewController? = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
    ) -> UIViewController? {
        if let navigationController = controller as? UINavigationController {
            return topViewController(from: navigationController.visibleViewController)
        }
        if let tabBarController = controller as? UITabBarController {
            return topViewController(from: tabBarController.selectedViewController)
        }
        if let presentedViewController = controller?.presentedViewController {
            return topViewController(from: presentedViewController)
        }
        return controller
    }
}
#endif

private struct RechargeNumericDatePicker: View {
    @Binding var selection: Date

    private let calendar = Calendar(identifier: .gregorian)
    private let years = Array(2020...2035)
    private let months = Array(1...12)

    var body: some View {
        VStack(spacing: DUSpacing.sm) {
            HStack(spacing: DUSpacing.sm) {
                pickerColumn(
                    values: years,
                    selection: yearBinding,
                    accessibilityLabel: "Year",
                    format: { String($0) }
                )
                pickerColumn(
                    values: months,
                    selection: monthBinding,
                    accessibilityLabel: "Month",
                    format: { String(format: "%02d", $0) }
                )
                pickerColumn(
                    values: days,
                    selection: dayBinding,
                    accessibilityLabel: "Day",
                    format: { String(format: "%02d", $0) }
                )
            }
            .frame(height: 180)
        }
    }

    private var components: DateComponents {
        calendar.dateComponents([.year, .month, .day], from: selection)
    }

    private var currentYear: Int {
        components.year ?? 2026
    }

    private var currentMonth: Int {
        components.month ?? 1
    }

    private var currentDay: Int {
        components.day ?? 1
    }

    private var days: [Int] {
        let date = calendar.date(from: DateComponents(year: currentYear, month: currentMonth, day: 1)) ?? selection
        let range = calendar.range(of: .day, in: .month, for: date) ?? 1..<32
        return Array(range)
    }

    private var yearBinding: Binding<Int> {
        Binding(
            get: { currentYear },
            set: { updateDate(year: $0, month: currentMonth, day: currentDay) }
        )
    }

    private var monthBinding: Binding<Int> {
        Binding(
            get: { currentMonth },
            set: { updateDate(year: currentYear, month: $0, day: currentDay) }
        )
    }

    private var dayBinding: Binding<Int> {
        Binding(
            get: { min(currentDay, days.last ?? currentDay) },
            set: { updateDate(year: currentYear, month: currentMonth, day: $0) }
        )
    }

    private func pickerColumn(
        values: [Int],
        selection: Binding<Int>,
        accessibilityLabel: String,
        format: @escaping (Int) -> String
    ) -> some View {
        Picker(accessibilityLabel, selection: selection) {
            ForEach(values, id: \.self) { value in
                Text(format(value)).tag(value)
            }
        }
        .labelsHidden()
        .pickerStyle(.wheel)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private func updateDate(year: Int, month: Int, day: Int) {
        let baseDate = calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? selection
        let maxDay = calendar.range(of: .day, in: .month, for: baseDate)?.count ?? 31
        let normalizedDay = min(day, maxDay)
        let newDate = calendar.date(from: DateComponents(year: year, month: month, day: normalizedDay)) ?? selection
        selection = newDate
    }
}

private struct RechargeOrderDetailView: View {
    @Environment(\.duTheme) private var theme
    @EnvironmentObject private var languageStore: AppLanguageStore

    let record: RechargeOrderRecord

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: DUSpacing.lg) {
                detailHero
                detailFacts

                if let failureMessageKey = record.failureMessageKey {
                    DUSectionCard(title: localized("recharge.orders.detail.failure")) {
                        Text(localized(failureMessageKey))
                            .font(.du(14, weight: .medium))
                            .foregroundColor(theme.colors.status.error)
                        Text(localized("recharge.orders.detail.failureHint"))
                            .font(.du(12, weight: .medium))
                            .foregroundColor(theme.colors.text.secondary)
                    }
                }
            }
            .padding(DUSpacing.lg)
            .padding(.bottom, DUSpacing.xxxl)
        }
        .background(theme.colors.background.canvas.ignoresSafeArea())
        .navigationTitle(localized("recharge.orders.detail.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var detailHero: some View {
        VStack(alignment: .leading, spacing: DUSpacing.lg) {
            Text(record.amountText)
                .font(.du(30, weight: .bold))
                .foregroundColor(.white)

            HStack(spacing: DUSpacing.md) {
                detailHeroMetric(
                    title: localized("recharge.orders.detail.status"),
                    value: localized(record.status.titleKey)
                )
                detailHeroMetric(
                    title: localized("recharge.receipt.chargeMethod"),
                    value: record.chargeMethod
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DUSpacing.xl)
        .background(theme.colors.gradient.brand)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func detailHeroMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.xs) {
            Text(title)
                .font(.du(10, weight: .medium))
                .foregroundColor(.white.opacity(0.72))
            Text(value)
                .font(.du(14, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DUSpacing.md)
        .background(Color.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var detailFacts: some View {
        DUSectionCard(title: localized("recharge.orders.listTitle")) {
            VStack(spacing: DUSpacing.md) {
                detailFactRow(title: localized("recharge.receipt.orderId"), value: record.orderId)
                detailFactRow(title: localized("recharge.orders.detail.created"), value: record.createdTimeText)
                detailFactRow(title: localized("recharge.orders.detail.number"), value: record.serviceNumber)
                detailFactRow(title: localized("recharge.orders.detail.amount"), value: record.amountText)
                detailFactRow(title: localized("recharge.orders.detail.status"), value: localized(record.status.titleKey))
                detailFactRow(title: localized("recharge.orders.detail.statusCode"), value: record.statusCode)
            }
        }
    }

    private func detailFactRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: DUSpacing.md) {
            Text(title)
                .font(.du(12, weight: .semibold))
                .foregroundColor(theme.colors.text.secondary)
            Spacer()
            Text(value)
                .font(.du(14, weight: .semibold))
                .foregroundColor(theme.colors.text.primary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func localized(_ key: String, arguments: [String] = []) -> String {
        languageStore.string(key, arguments: arguments)
    }
}

private struct RechargeConfirmView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.duTheme) private var theme
    @ObservedObject var viewModel: RechargeViewModel

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: DUSpacing.lg) {
                    VStack(alignment: .leading, spacing: DUSpacing.sm) {
                        Text("Confirm Payment")
                            .font(.du(22, weight: .bold))
                            .foregroundColor(theme.colors.text.primary)
                        Text("Verify the current number and recharge details before the request is accepted.")
                            .font(.du(13, weight: .medium))
                            .foregroundColor(theme.colors.text.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: DUSpacing.md) {
                        rechargeConfirmMetric(title: "Current Number", value: viewModel.serviceNumberText)
                        rechargeConfirmMetric(title: "Amount", value: BillingNumberParser.displayMoney(viewModel.amountText))
                        rechargeConfirmMetric(title: "chargeMethod", value: viewModel.selectedPaymentMethod.requestValue)
                        rechargeConfirmMetric(title: "Execution Route", value: "MobileMoney")
                    }
                    .padding(DUSpacing.lg)
                    .background(theme.colors.surface.card)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                    DUButton(
                        title: "Submit Recharge",
                        style: .primary,
                        isLoading: viewModel.isSubmitting
                    ) {
                        Task {
                            await viewModel.submitRecharge()
                        }
                    }
                }
                .padding(DUSpacing.lg)
            }
            .background(theme.colors.background.canvas.ignoresSafeArea())
            .navigationTitle("Confirm Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func rechargeConfirmMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.xs) {
            Text(title)
                .font(.du(11, weight: .medium))
                .foregroundColor(theme.colors.text.secondary)
            Text(value)
                .font(.du(15, weight: .semibold))
                .foregroundColor(theme.colors.text.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RechargeAcceptedView: View {
    @Environment(\.duTheme) private var theme
    let receipt: RechargeAcceptedReceipt
    let serviceNumber: String
    let onBackToOrders: () -> Void
    let onSaveSnapshot: () -> Void
    let onShare: () -> Void

    var body: some View {
        ZStack {
            theme.colors.background.canvas.ignoresSafeArea()

            NavigationView {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: DUSpacing.lg) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 56, weight: .bold))
                            .foregroundColor(theme.colors.status.success)

                        VStack(spacing: DUSpacing.xs) {
                            Text("Recharge Accepted")
                                .font(.du(24, weight: .bold))
                                .foregroundColor(theme.colors.text.primary)
                            Text("The recharge request was accepted. Tap back to review the latest status in Orders.")
                                .font(.du(13, weight: .medium))
                                .foregroundColor(theme.colors.text.secondary)
                                .multilineTextAlignment(.center)
                        }

                        RechargeReceiptSnapshotCard(
                            receipt: receipt,
                            serviceNumber: serviceNumber,
                            localizedTitle: "Recharge Receipt"
                        )

                        HStack(spacing: DUSpacing.md) {
                            DUButton(title: "Save Screenshot", style: .secondary, fontSize: 14) {
                                onSaveSnapshot()
                            }
                            DUButton(title: "Share Receipt", style: .primary, fontSize: 14) {
                                onShare()
                            }
                        }

                        DUButton(title: "Back to Orders", style: .primary) {
                            onBackToOrders()
                        }
                    }
                    .padding(DUSpacing.lg)
                    .padding(.bottom, DUSpacing.xxxl)
                }
                .background(theme.colors.background.canvas)
                .navigationBarHidden(true)
            }
        }
        .navigationViewStyle(.stack)
    }
}

private struct RechargeFailureView: View {
    @Environment(\.duTheme) private var theme
    let failure: RechargeFailureFeedback
    let amountText: String
    let chargeMethod: String
    let onRetry: () -> Void
    let onBack: () -> Void

    var body: some View {
        ZStack {
            theme.colors.background.canvas.ignoresSafeArea()

            NavigationView {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: DUSpacing.lg) {
                        Image(systemName: "xmark.octagon.fill")
                            .font(.system(size: 56, weight: .bold))
                            .foregroundColor(theme.colors.status.error)

                        Text("Recharge Failed")
                            .font(.du(24, weight: .bold))
                            .foregroundColor(theme.colors.text.primary)

                        Text(failure.message)
                            .font(.du(13, weight: .medium))
                            .foregroundColor(theme.colors.text.secondary)
                            .multilineTextAlignment(.center)

                        VStack(spacing: DUSpacing.md) {
                            rechargeFailureMetric(title: "Amount", value: BillingNumberParser.displayMoney(amountText))
                            rechargeFailureMetric(title: "chargeMethod", value: chargeMethod)
                            rechargeFailureMetric(title: "Execution Route", value: "MobileMoney")
                        }
                        .padding(DUSpacing.lg)
                        .background(theme.colors.surface.card)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                        HStack(spacing: DUSpacing.md) {
                            DUButton(title: "Retry", style: .primary) {
                                onRetry()
                            }
                            DUButton(title: "Back", style: .secondary) {
                                onBack()
                            }
                        }
                    }
                    .padding(DUSpacing.lg)
                    .padding(.bottom, DUSpacing.xxxl)
                }
                .background(theme.colors.background.canvas)
                .navigationBarHidden(true)
            }
        }
        .navigationViewStyle(.stack)
    }

    private func rechargeFailureMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.xs) {
            Text(title)
                .font(.du(11, weight: .medium))
                .foregroundColor(theme.colors.text.secondary)
            Text(value)
                .font(.du(15, weight: .semibold))
                .foregroundColor(theme.colors.text.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RechargeReceiptSnapshotCard: View {
    @Environment(\.duTheme) private var theme
    let receipt: RechargeAcceptedReceipt
    let serviceNumber: String
    let localizedTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: DUSpacing.md) {
            Text(localizedTitle)
                .font(.du(16, weight: .bold))
                .foregroundColor(.white)

            Text(receipt.amountText)
                .font(.du(30, weight: .bold))
                .foregroundColor(.white)

            HStack(spacing: DUSpacing.md) {
                receiptMetric(title: "Current Number", value: serviceNumber)
                receiptMetric(title: "Status", value: receipt.submissionStatusText)
            }

            HStack(spacing: DUSpacing.md) {
                receiptMetric(title: "Order ID", value: receipt.orderId)
                receiptMetric(title: "chargeMethod", value: receipt.requestChargeMethod)
            }
        }
        .padding(DUSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.colors.gradient.brand)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func receiptMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.xs) {
            Text(title)
                .font(.du(10, weight: .medium))
                .foregroundColor(.white.opacity(0.72))
            Text(value)
                .font(.du(13, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if canImport(UIKit)
private enum RechargeSnapshotRenderer {
    static func makeImage(
        receipt: RechargeAcceptedReceipt,
        serviceNumber: String,
        localizedTitle: String
    ) -> UIImage? {
        let content = RechargeReceiptSnapshotCard(
            receipt: receipt,
            serviceNumber: serviceNumber,
            localizedTitle: localizedTitle
        )
        .frame(width: 360)
        .padding()
        .background(DUColorTokens.Background.canvas.light)

        let controller = UIHostingController(rootView: content)
        let view = controller.view
        let targetSize = CGSize(width: 392, height: 320)
        view?.bounds = CGRect(origin: .zero, size: targetSize)
        view?.backgroundColor = .clear

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            view?.drawHierarchy(in: CGRect(origin: .zero, size: targetSize), afterScreenUpdates: true)
        }
    }
}
#endif
