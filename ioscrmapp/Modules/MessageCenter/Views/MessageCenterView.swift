import SwiftUI

struct MessageCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.duTheme) private var theme
    @EnvironmentObject private var languageStore: AppLanguageStore

    @StateObject private var viewModel: MessageCenterViewModel
    @State private var pendingConfirmation: PendingConfirmation?
    private let session: CustSubInfo
    private let aiChatService: any AIChatServicing
    private let onAIChatNavigation: (AIChatNavigationTarget) -> Void

    init(
        session: CustSubInfo,
        notificationService: any NotificationServicing,
        aiChatService: any AIChatServicing,
        onAIChatNavigation: @escaping (AIChatNavigationTarget) -> Void = { _ in }
    ) {
        self.session = session
        _viewModel = StateObject(
            wrappedValue: MessageCenterViewModel(
                session: session,
                notificationService: notificationService
            )
        )
        self.aiChatService = aiChatService
        self.onAIChatNavigation = onAIChatNavigation
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if let banner = viewModel.banner {
                MessageCenterBannerView(
                    message: localized(banner.message),
                    style: banner.style
                )
                .padding(.horizontal, DUSpacing.lg)
                .padding(.bottom, DUSpacing.sm)
            }

            Divider()
                .background(theme.colors.border.subtle)

            content
        }
        .accessibilityIdentifier(
            viewModel.selectedMessage == nil
                ? "messageCenter.list.page"
                : "messageCenter.detail.page"
        )
        .background(screenBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            if viewModel.selectionMode {
                selectionActionBar
            }
        }
        .task {
            await viewModel.loadIfNeeded()
        }
        .alert(item: $pendingConfirmation) { confirmation in
            alert(for: confirmation)
        }
        .businessAIAssistant(
            session: session,
            aiChatService: aiChatService,
            onNavigate: handleAIChatNavigation(_:)
        )
    }

    @ViewBuilder
    private var content: some View {
        if let selectedMessage = viewModel.selectedMessage {
            MessageDetailContentView(
                message: selectedMessage,
                language: languageStore.currentLanguage,
                locale: languageStore.locale
            )
        } else {
            switch viewModel.screenState {
            case .idle, .loading:
                loadingState
            case .empty:
                DUStateView(
                    systemImage: "tray",
                    iconColor: theme.colors.text.disabled,
                    title: localized("messageCenter.empty.title"),
                    subtitle: localized("messageCenter.empty.subtitle")
                )
            case let .failed(message):
                DUStateView(
                    systemImage: "wifi.exclamationmark",
                    iconColor: theme.colors.status.warning,
                    title: localized("messageCenter.error.title"),
                    subtitle: localized(message),
                    actionTitle: localized("messageCenter.action.retry"),
                    actionStyle: .secondary,
                    action: {
                        Task { await viewModel.reload() }
                    }
                )
            case .loaded:
                messageList
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: DUSpacing.lg) {
            ProgressView()
                .tint(theme.colors.action.primary)

            Text(localized("messageCenter.loading"))
                .font(.du(.body))
                .foregroundColor(theme.colors.text.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var messageList: some View {
        List {
            ForEach(viewModel.messages) { message in
                messageCardRow(message)
                    .listRowInsets(EdgeInsets(top: DUSpacing.xs, leading: 0, bottom: DUSpacing.xs, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(DUColorPrimitives.Chrome.transparent)
            }
        }
        .listStyle(.plain)
        .modifier(MessageCenterListBackgroundModifier())
        .background(theme.colors.background.canvas)
        .accessibilityIdentifier("messageCenter.list.list")
        .refreshable {
            await viewModel.reload()
        }
    }

    @ViewBuilder
    private func messageCardRow(_ message: MessageCenterMessage) -> some View {
        let rowView = MessageRowView(
            message: message,
            language: languageStore.currentLanguage,
            isSelectionMode: viewModel.selectionMode,
            isSelected: viewModel.selectedMessageIDs.contains(message.id),
            action: {
                viewModel.openMessage(message)
            },
            longPressAction: {
                viewModel.enterSelectionMode(with: message.id)
            }
        )
        .padding(.horizontal, DUSpacing.lg)
        .padding(.vertical, DUSpacing.xs)

        if viewModel.selectionMode {
            rowView
        } else {
            rowView
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        Task { await viewModel.deleteMessage(message.id) }
                    } label: {
                        Label(
                            localized("messageCenter.action.delete"),
                            systemImage: "trash.fill"
                        )
                    }
                    .tint(theme.colors.status.error)
                }
        }
    }

    private var header: some View {
        HStack(spacing: DUSpacing.md) {
            Button(action: handleBack) {
                HStack(spacing: DUSpacing.sm) {
                    Image(systemName: "chevron.backward")
                        .font(.du(.bodyEmphasized))
                    Text(localized("messageCenter.action.back"))
                        .font(.du(.bodyStrong))
                }
                .foregroundColor(theme.colors.text.primary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(
                viewModel.selectedMessage == nil
                    ? "messageCenter.list.backButton"
                    : "messageCenter.detail.backButton"
            )

            Spacer()

            VStack(spacing: DUSpacing.xs) {
                Text(headerTitle)
                    .font(.du(.title))
                    .foregroundColor(theme.colors.text.primary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            headerTrailingView
        }
        .padding(.horizontal, DUSpacing.lg)
        .padding(.top, DUSpacing.md)
        .padding(.bottom, DUSpacing.md)
        .background(theme.colors.surface.card)
    }

    private var screenBackground: Color {
        viewModel.selectedMessage == nil ? theme.colors.surface.card : theme.colors.background.canvas
    }

    @ViewBuilder
    private var headerTrailingView: some View {
        if viewModel.selectedMessage != nil {
            DUColorPrimitives.Chrome.transparent
                .frame(width: 82, height: 32)
        } else if viewModel.selectionMode {
            DUTextButton(
                title: localized(
                    viewModel.allMessagesSelected
                        ? "messageCenter.action.deselectAll"
                        : "messageCenter.action.selectAll"
                ),
                textStyle: .bodySmallStrong
            ) {
                viewModel.toggleSelectAll()
            }
            .accessibilityIdentifier("messageCenter.list.selectAllButton")
        } else {
            MessageBellBadgeView(unreadCount: viewModel.unreadCount)
        }
    }

    private var selectionActionBar: some View {
        VStack(spacing: DUSpacing.md) {
            Divider()
                .background(theme.colors.border.subtle)

            HStack(spacing: DUSpacing.md) {
                DUButton(
                    title: localized("messageCenter.action.cancel"),
                    style: .secondary,
                    isEnabled: viewModel.inFlightBatchAction == nil,
                    height: 48,
                    fixedWidth: 104,
                    action: {
                        viewModel.exitSelectionMode()
                    }
                ) 
                .accessibilityIdentifier("messageCenter.list.cancelSelectionButton")

                DUButton(
                    title: localized("messageCenter.action.markRead"),
                    style: .secondary,
                    isLoading: viewModel.inFlightBatchAction == .markRead,
                    isEnabled: viewModel.canBatchMarkRead && viewModel.inFlightBatchAction == nil,
                    height: 48,
                    action: {
                        pendingConfirmation = .markRead(count: viewModel.selectedCount)
                    }
                )
                .accessibilityIdentifier("messageCenter.list.markReadButton")

                DUButton(
                    title: localized("messageCenter.action.delete"),
                    style: .danger,
                    isLoading: viewModel.inFlightBatchAction == .delete,
                    isEnabled: viewModel.selectedCount > 0 && viewModel.inFlightBatchAction == nil,
                    height: 48,
                    action: {
                        pendingConfirmation = .delete(count: viewModel.selectedCount)
                    }
                )
                .accessibilityIdentifier("messageCenter.list.deleteSelectedButton")
            }
            .padding(.horizontal, DUSpacing.lg)
            .padding(.bottom, DUSpacing.md)
        }
        .background(theme.colors.surface.card)
        .accessibilityIdentifier("messageCenter.list.selectionBar")
    }

    private var headerTitle: String {
        if viewModel.selectionMode {
            return localized("messageCenter.selection.count", arguments: ["\(viewModel.selectedCount)"])
        }

        if viewModel.selectedMessage != nil {
            return localized("messageCenter.detail.title")
        }

        return localized("messageCenter.title")
    }

    private func handleBack() {
        if viewModel.selectionMode {
            viewModel.exitSelectionMode()
            return
        }

        if viewModel.selectedMessage != nil {
            viewModel.closeDetail()
            return
        }

        dismiss()
    }

    private func alert(for confirmation: PendingConfirmation) -> Alert {
        switch confirmation {
        case let .markRead(count):
            return Alert(
                title: Text(localized("messageCenter.confirm.markRead.title")),
                message: Text(localized("messageCenter.confirm.markRead.message", arguments: ["\(count)"])),
                primaryButton: .default(Text(localized("messageCenter.action.markRead"))) {
                    Task { await viewModel.markSelectedMessagesRead() }
                },
                secondaryButton: .cancel(Text(localized("messageCenter.action.cancel")))
            )
        case let .delete(count):
            return Alert(
                title: Text(localized("messageCenter.confirm.delete.title")),
                message: Text(localized("messageCenter.confirm.delete.message", arguments: ["\(count)"])),
                primaryButton: .destructive(Text(localized("messageCenter.action.delete"))) {
                    Task { await viewModel.deleteSelectedMessages() }
                },
                secondaryButton: .cancel(Text(localized("messageCenter.action.cancel")))
            )
        }
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
        case .external:
            return false
        default:
            return true
        }
    }

    private func localized(_ key: String, arguments: [String] = []) -> String {
        languageStore.string(key, arguments: arguments)
    }

    private func localized(_ value: LocalizedTextValue) -> String {
        languageStore.string(value)
    }
}

private enum PendingConfirmation: Identifiable {
    case markRead(count: Int)
    case delete(count: Int)

    var id: String {
        switch self {
        case let .markRead(count):
            return "markRead-\(count)"
        case let .delete(count):
            return "delete-\(count)"
        }
    }
}

private struct MessageCenterBannerView: View {
    @Environment(\.duTheme) private var theme

    let message: String
    let style: MessageCenterBannerStyle

    var body: some View {
        HStack(spacing: DUSpacing.sm) {
            Image(systemName: style == .error ? "exclamationmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(style == .error ? theme.colors.status.error : theme.colors.status.warning)

            Text(message)
                .font(.du(.label))
                .foregroundColor(theme.colors.text.primary)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, DUSpacing.md)
        .padding(.vertical, DUSpacing.md)
        .background(style == .error ? theme.colors.status.errorBackground : theme.colors.status.warningBackground)
        .clipShape(RoundedRectangle(cornerRadius: theme.components.field.cornerRadius, style: .continuous))
        .accessibilityIdentifier("messageCenter.list.banner")
    }
}

private struct MessageBellBadgeView: View {
    @Environment(\.duTheme) private var theme

    let unreadCount: Int

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Circle()
                .fill(theme.colors.background.secondary)
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: "bell.fill")
                        .font(.du(.bodySmallStrong))
                        .foregroundColor(theme.colors.text.primary)
                )

            if unreadCount > 0 {
                Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
                    .font(.du(.microStrong))
                    .foregroundColor(DUColorPrimitives.Neutral.white)
                    .padding(.horizontal, DUSpacing.smd)
                    .frame(height: 18)
                    .background(theme.colors.status.error)
                    .clipShape(Capsule())
                    .offset(x: 8, y: -6)
            }
        }
        .frame(width: 82, alignment: .trailing)
        .accessibilityIdentifier("messageCenter.list.unreadBadge")
    }
}

private struct MessageCenterListBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollContentBackground(.hidden)
        } else {
            content
        }
    }
}

private struct MessageRowView: View {
    @Environment(\.duTheme) private var theme

    let message: MessageCenterMessage
    let language: AppLanguage
    let isSelectionMode: Bool
    let isSelected: Bool
    let action: () -> Void
    let longPressAction: () -> Void
    @State private var suppressNextTap = false

    private var cornerRadius: CGFloat {
        theme.components.card.cornerRadius
    }

    private var cellIdentifier: String {
        "messageCenter.list.messageCell.\(message.accessibilityKey)"
    }

    var body: some View {
        HStack(alignment: .top, spacing: DUSpacing.md) {
            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.du(.titleStrongSemibold))
                    .foregroundColor(isSelected ? theme.colors.action.primary : theme.colors.text.disabled)
                    .padding(.top, DUSpacing.sm)
                    .accessibilityIdentifier("\(cellIdentifier).selectionIndicator")
            }

            MessageAvatarView(message: message)
                .padding(.top, DUSpacing.xxs)
                .accessibilityIdentifier("\(cellIdentifier).avatar")

            VStack(alignment: .leading, spacing: DUSpacing.sm) {
                HStack(alignment: .top, spacing: DUSpacing.md) {
                    Text(message.displaySender())
                        .font(.du(message.isRead ? .bodyLargeSemibold : .bodyLargeStrong))
                        .foregroundColor(theme.colors.text.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(1)
                        .accessibilityIdentifier("\(cellIdentifier).senderLabel")

                    Spacer(minLength: DUSpacing.sm)

                    VStack(alignment: .trailing, spacing: DUSpacing.sm) {
                        Text(rowDateText)
                            .font(.du(.caption))
                            .foregroundColor(theme.colors.text.tertiary)
                            .accessibilityIdentifier("\(cellIdentifier).timeLabel")

                        if !message.isRead {
                            Circle()
                                .fill(theme.colors.status.error)
                                .frame(width: 10, height: 10)
                                .overlay(
                                    Circle()
                                        .stroke(theme.colors.surface.card, lineWidth: 2)
                                )
                                .accessibilityIdentifier("\(cellIdentifier).unreadBadge")
                        }
                    }
                }

                Text(message.summary(for: language))
                    .font(.du(.bodySmall))
                    .foregroundColor(message.isRead ? theme.colors.text.secondary : theme.colors.text.primary)
                    .lineLimit(1)
                    .multilineTextAlignment(.leading)
                    .accessibilityIdentifier("\(cellIdentifier).subjectLabel")

                Text(contentPreviewText)
                    .font(.du(.labelRegular))
                    .foregroundColor(theme.colors.text.tertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
                    .accessibilityIdentifier("\(cellIdentifier).previewLabel")
            }
        }
        .padding(.horizontal, DUSpacing.lg)
        .padding(.vertical, DUSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .overlay(cardBorder)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityIdentifier(cellIdentifier)
        .onTapGesture(perform: handleTap)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.42)
                .onEnded { _ in
                    handleLongPress()
                }
        )
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(cardHighlightColor)
                    .blendMode(.plusLighter)
            )
    }

    private var cardFill: LinearGradient {
        if isSelectionMode && isSelected {
            return LinearGradient(
                colors: [theme.colors.action.primaryBackground.opacity(0.9), theme.colors.surface.card],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        if !message.isRead {
            return LinearGradient(
                colors: [theme.colors.surface.card, theme.colors.background.canvas],
                startPoint: .top,
                endPoint: .bottom
            )
        }

        return LinearGradient(
            colors: [theme.colors.surface.card.opacity(0.98), theme.colors.surface.raised],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(borderColor, lineWidth: borderWidth)
    }

    private var borderColor: Color {
        if isSelectionMode && isSelected {
            return theme.colors.action.primary.opacity(0.32)
        }

        if !message.isRead {
            return theme.colors.action.primary.opacity(0.16)
        }

        return theme.colors.border.subtle
    }

    private var borderWidth: CGFloat {
        isSelectionMode && isSelected ? 1.4 : 1
    }

    private var cardHighlightColor: Color {
        switch theme.resolvedColorScheme {
        case .dark:
            return DUColorPrimitives.Neutral.white.opacity(message.isRead ? 0.04 : 0.08)
        case .light:
            fallthrough
        @unknown default:
            return DUColorPrimitives.Neutral.white.opacity(message.isRead ? 0.08 : 0.20)
        }
    }

    private var rowDateText: String {
        guard let createdAt = message.createdAt else {
            return relativeDateText(for: Date())
        }

        return relativeDateText(for: createdAt)
    }

    private var contentPreviewText: String {
        let localizedContent: String

        switch language {
        case .arabic:
            let arabicContent = message.contentPreviewText(arabicPreferred: true)
            localizedContent = arabicContent
        case .english, .simplifiedChinese:
            localizedContent = message.contentPreviewText(arabicPreferred: false)
        }

        return localizedContent
    }

    private func relativeDateText(for date: Date) -> String {
        let seconds = max(0, Int(Date().timeIntervalSince(date)))
        let minutes = max(1, seconds / 60)
        let hours = max(1, seconds / 3_600)
        let days = max(1, seconds / 86_400)
        let months = max(1, days / 30)
        let years = max(1, days / 365)

        if seconds < 3_600 {
            return localizedRelative("messageCenter.relative.minutesAgo", value: minutes)
        }

        if seconds < 86_400 {
            return localizedRelative("messageCenter.relative.hoursAgo", value: hours)
        }

        if days < 30 {
            return localizedRelative("messageCenter.relative.daysAgo", value: days)
        }

        if days < 365 {
            return localizedRelative("messageCenter.relative.monthsAgo", value: months)
        }

        return localizedRelative("messageCenter.relative.yearsAgo", value: years)
    }

    private func localizedRelative(_ key: String, value: Int? = nil) -> String {
        switch language {
        case .english:
            switch key {
            case "messageCenter.relative.minutesAgo":
                let count = value ?? 0
                return count == 1 ? "1 min ago" : "\(count) min ago"
            case "messageCenter.relative.hoursAgo":
                let count = value ?? 0
                return count == 1 ? "1 hr ago" : "\(count) hrs ago"
            case "messageCenter.relative.daysAgo":
                let count = value ?? 0
                return count == 1 ? "1 day ago" : "\(count) days ago"
            case "messageCenter.relative.monthsAgo":
                let count = value ?? 0
                return count == 1 ? "1 month ago" : "\(count) months ago"
            case "messageCenter.relative.yearsAgo":
                let count = value ?? 0
                return count == 1 ? "1 year ago" : "\(count) years ago"
            default:
                return ""
            }
        case .simplifiedChinese:
            switch key {
            case "messageCenter.relative.minutesAgo":
                return "\(value ?? 0)分钟前"
            case "messageCenter.relative.hoursAgo":
                return "\(value ?? 0)小时前"
            case "messageCenter.relative.daysAgo":
                return "\(value ?? 0)天前"
            case "messageCenter.relative.monthsAgo":
                return "\(value ?? 0)月前"
            case "messageCenter.relative.yearsAgo":
                return "\(value ?? 0)年前"
            default:
                return ""
            }
        case .arabic:
            switch key {
            case "messageCenter.relative.minutesAgo":
                return "منذ \(value ?? 0) دقيقة"
            case "messageCenter.relative.hoursAgo":
                return "منذ \(value ?? 0) ساعة"
            case "messageCenter.relative.daysAgo":
                return "منذ \(value ?? 0) يوم"
            case "messageCenter.relative.monthsAgo":
                return "منذ \(value ?? 0) شهر"
            case "messageCenter.relative.yearsAgo":
                return "منذ \(value ?? 0) سنة"
            default:
                return ""
            }
        }
    }

    private func handleTap() {
        if suppressNextTap {
            suppressNextTap = false
            return
        }
        action()
    }

    private func handleLongPress() {
        guard !isSelectionMode else {
            return
        }
        suppressNextTap = true
        longPressAction()
    }
}

private extension MessageCenterMessage {
    var accessibilityKey: String {
        String(
            id.map { character in
                if character.isLetter || character.isNumber || character == "-" || character == "_" {
                    return character
                }
                return "_"
            }
        )
    }

    func contentPreviewText(arabicPreferred: Bool) -> String {
        let primaryText = arabicPreferred ? arabicContent : content
        let secondaryText = arabicPreferred ? content : arabicContent

        let trimmedPrimaryText = primaryText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPrimaryText.isEmpty {
            return trimmedPrimaryText
        }

        let trimmedSecondaryText = secondaryText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSecondaryText.isEmpty {
            return trimmedSecondaryText
        }

        return title.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct MessageAvatarView: View {
    @Environment(\.duTheme) private var theme

    let message: MessageCenterMessage

    var body: some View {
        ZStack {
            Circle()
                .fill(avatarGradient)
                .frame(width: 48, height: 48)

            Text(avatarText)
                .font(.du(.bodyEmphasized))
                .foregroundColor(DUColorPrimitives.Neutral.white)
        }
        .opacity(message.isRead ? 0.78 : 1)
        .overlay(
            Circle()
                .stroke(DUColorPrimitives.Neutral.white.opacity(0.35), lineWidth: 1)
        )
    }

    private var avatarGradient: LinearGradient {
        switch message.category {
        case .system:
            return LinearGradient(
                colors: [theme.colors.brand.secondaryLight, theme.colors.brand.secondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .promotion:
            return LinearGradient(
                colors: [theme.colors.brand.magenta.opacity(0.78), theme.colors.brand.indigo],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .other:
            return LinearGradient(
                colors: [theme.colors.brand.primaryLight, theme.colors.brand.primary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var avatarText: String {
        let words = message
            .displaySender()
            .split(whereSeparator: \.isWhitespace)
            .prefix(2)
            .compactMap { $0.first.map(String.init) }

        if !words.isEmpty {
            return words.joined().uppercased()
        }

        return String(message.displaySender().prefix(2)).uppercased()
    }
}

struct MessageCenterView_Previews: PreviewProvider {
    static var previews: some View {
        MessageCenterView(
            session: CustSubInfo(
                displayName: "Ahmed Mohammed",
                phoneNumber: AuthValidator.demoPhone,
                greeting: "Good Morning",
                balanceText: "128.50 AED",
                userID: "preview-user",
                serviceNumber: AuthValidator.demoPhone
            ),
            notificationService: MockNotificationService(),
            aiChatService: MockAIChatService()
        )
        .environmentObject(AppLanguageStore(initialLanguage: .english))
    }
}
