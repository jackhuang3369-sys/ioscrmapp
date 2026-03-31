import SwiftUI

struct AIChatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @StateObject private var viewModel: AIChatViewModel

    let onNavigate: (AIChatNavigationTarget) -> Void

    init(
        custSubInfo: CustSubInfo,
        language: AppLanguage,
        aiChatService: any AIChatServicing,
        onNavigate: @escaping (AIChatNavigationTarget) -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: AIChatViewModel(
                custSubInfo: custSubInfo,
                language: language,
                aiChatService: aiChatService
            )
        )
        self.onNavigate = onNavigate
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()
                .overlay(DUTheme.line)

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: DUSpacing.lg) {
                        welcomeBlock

                        ForEach(viewModel.messages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, DUSpacing.lg)
                    .padding(.top, DUSpacing.lg)
                    .padding(.bottom, DUSpacing.xxl)
                }
                .background(DUTheme.background)
                .onChange(of: viewModel.messages.map(\.id)) { _ in
                    guard let lastID = viewModel.messages.last?.id else {
                        return
                    }

                    DispatchQueue.main.async {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(lastID, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .background(DUTheme.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            inputBar
                .background(DUTheme.panel)
        }
        .alert(
            AIChatLocalizedCopy.newChatTitle(for: viewModel.language),
            isPresented: $viewModel.confirmResetPresented
        ) {
            Button(AIChatLocalizedCopy.newChatTitle(for: viewModel.language), role: .destructive) {
                viewModel.confirmNewChat()
            }
            Button(AIChatLocalizedCopy.closeTitle(for: viewModel.language), role: .cancel) {}
        } message: {
            Text(viewModel.subtitle)
        }
    }

    private var header: some View {
        HStack(spacing: DUSpacing.md) {
            ZStack {
                Circle()
                    .fill(DUTheme.brandGradient)
                    .frame(width: 42, height: 42)

                Image(systemName: "sparkles")
                    .font(.du(18, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.title)
                    .font(.du(18, weight: .bold))
                    .foregroundColor(DUTheme.ink)

                Text(viewModel.subtitle)
                    .font(.du(12, weight: .medium))
                    .foregroundColor(DUTheme.inkSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Button {
                viewModel.requestNewChat()
            } label: {
                Image(systemName: "plus.bubble")
                    .font(.du(16, weight: .semibold))
                    .foregroundColor(DUTheme.ink)
                    .frame(width: 40, height: 40)
                    .background(DUTheme.backgroundSecondary)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.du(16, weight: .bold))
                    .foregroundColor(DUTheme.ink)
                    .frame(width: 40, height: 40)
                    .background(DUTheme.backgroundSecondary)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DUSpacing.lg)
        .padding(.vertical, DUSpacing.md)
        .background(DUTheme.panel)
    }

    private var welcomeBlock: some View {
        VStack(alignment: .leading, spacing: DUSpacing.lg) {
            VStack(alignment: .leading, spacing: DUSpacing.sm) {
                Text(viewModel.title)
                    .font(.du(26, weight: .bold))
                    .foregroundColor(DUTheme.ink)

                Text(viewModel.subtitle)
                    .font(.du(14, weight: .medium))
                    .foregroundColor(DUTheme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: DUSpacing.md) {
                Text(AIChatLocalizedCopy.recommendedTitle(for: viewModel.language))
                    .font(.du(14, weight: .semibold))
                    .foregroundColor(DUTheme.inkSecondary)

                ForEach(viewModel.suggestedPrompts, id: \.self) { prompt in
                    Button {
                        viewModel.sendSuggestedPrompt(prompt)
                    } label: {
                        HStack(spacing: DUSpacing.md) {
                            Image(systemName: "arrow.up.left.circle.fill")
                                .foregroundColor(DUTheme.cyan)

                            Text(prompt)
                                .font(.du(14, weight: .medium))
                                .foregroundColor(DUTheme.ink)
                                .multilineTextAlignment(.leading)

                            Spacer()
                        }
                        .padding(.horizontal, DUSpacing.lg)
                        .padding(.vertical, DUSpacing.md)
                        .background(DUTheme.panel)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(DUTheme.lineLight, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(DUSpacing.xl)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [DUTheme.cyanBackground, Color.white]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func messageBubble(_ message: AIChatMessage) -> some View {
        HStack(alignment: .top, spacing: DUSpacing.sm) {
            if message.sender == .assistant {
                avatarView(systemName: "sparkles")
            }

            VStack(alignment: message.sender == .user ? .trailing : .leading, spacing: DUSpacing.sm) {
                if message.sender == .assistant, !message.thinkingText.isEmpty {
                    DisclosureGroup(AIChatLocalizedCopy.thinkingTitle(for: viewModel.language)) {
                        Text(message.thinkingText)
                            .font(.du(12))
                            .foregroundColor(DUTheme.inkSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, DUSpacing.xs)
                    }
                    .font(.du(12, weight: .semibold))
                    .foregroundColor(DUTheme.blue)
                    .padding(DUSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DUTheme.cyanBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                Group {
                    if message.isLoading {
                        HStack(spacing: DUSpacing.sm) {
                            ProgressView()
                                .progressViewStyle(.circular)
                            Text(AIChatLocalizedCopy.loadingTitle(for: viewModel.language))
                                .font(.du(13, weight: .medium))
                                .foregroundColor(DUTheme.inkSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else if message.sender == .assistant, let richText = message.richText {
                        assistantRichTextView(richText)
                    } else {
                        Text(message.text)
                            .font(.du(14, weight: .medium))
                            .foregroundColor(message.sender == .user ? .white : DUTheme.ink)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, DUSpacing.lg)
                .padding(.vertical, DUSpacing.md)
                .background(message.sender == .user ? AnyShapeStyle(DUTheme.brandGradient) : AnyShapeStyle(DUTheme.panel))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(message.sender == .user ? Color.clear : DUTheme.lineLight, lineWidth: 1)
                )

                if !message.actions.isEmpty {
                    VStack(alignment: .leading, spacing: DUSpacing.sm) {
                        ForEach(message.actions) { action in
                            Button {
                                handleAction(action)
                            } label: {
                                HStack {
                                    Text(action.title)
                                        .font(.du(13, weight: .semibold))
                                        .foregroundColor(DUTheme.blue)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                    Image(systemName: "arrow.right")
                                        .font(.du(12, weight: .bold))
                                        .foregroundColor(DUTheme.blue)
                                }
                                .padding(.horizontal, DUSpacing.lg)
                                .padding(.vertical, DUSpacing.md)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(DUTheme.lineLight, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.du(11, weight: .medium))
                    .foregroundColor(DUTheme.inkDisabled)
            }
            .frame(maxWidth: .infinity, alignment: message.sender == .user ? .trailing : .leading)

            if message.sender == .user {
                avatarView(systemName: "person.fill")
            }
        }
        .frame(maxWidth: .infinity, alignment: message.sender == .user ? .trailing : .leading)
    }

    private func assistantRichTextView(_ richText: AttributedString) -> some View {
        Text(richText)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func avatarView(systemName: String) -> some View {
        ZStack {
            Circle()
                .fill(DUTheme.subtleGradient)
                .frame(width: 38, height: 38)

            Image(systemName: systemName)
                .font(.du(14, weight: .bold))
                .foregroundColor(.white)
        }
    }

    private var inputBar: some View {
        HStack(spacing: DUSpacing.md) {
            TextField(
                AIChatLocalizedCopy.inputPlaceholder(for: viewModel.language),
                text: $viewModel.draft
            )
            .font(.du(14, weight: .medium))
            .foregroundColor(DUTheme.ink)
            .padding(.horizontal, DUSpacing.lg)
            .padding(.vertical, DUSpacing.md)
            .background(DUTheme.background)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            Button {
                viewModel.sendDraft()
            } label: {
                Text(AIChatLocalizedCopy.sendButtonTitle(for: viewModel.language))
                    .font(.du(14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, DUSpacing.lg)
                    .frame(height: 48)
                    .background(viewModel.canSend ? AnyShapeStyle(DUTheme.brandGradient) : AnyShapeStyle(DUTheme.inkDisabled))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canSend)
        }
        .padding(.horizontal, DUSpacing.lg)
        .padding(.top, DUSpacing.md)
        .padding(.bottom, DUSpacing.md)
    }

    private func handleAction(_ action: AIChatAction) {
        guard let target = action.target else {
            return
        }

        switch target {
        case let .external(url):
            openURL(url)
        default:
            onNavigate(target)
        }
    }
}
