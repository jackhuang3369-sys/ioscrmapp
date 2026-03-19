import SwiftUI

struct MessageDetailContentView: View {
    let message: MessageCenterMessage
    let language: AppLanguage
    let locale: Locale

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: DUSpacing.lg) {
                VStack(alignment: .leading, spacing: DUSpacing.lg) {
                    detailHeader
                    Divider()

                    VStack(alignment: .leading, spacing: DUSpacing.md) {
                        Text(message.detailTitle(for: language))
                            .font(.du(24, weight: .bold))
                            .foregroundColor(DUTheme.ink)
                            .multilineTextAlignment(.leading)
                            .accessibilityIdentifier("messageCenter.detail.titleLabel")

                        Text(message.detailBody(for: language))
                            .font(.du(15, weight: .medium))
                            .foregroundColor(DUTheme.inkSecondary)
                            .multilineTextAlignment(.leading)
                            .lineSpacing(4)
                            .accessibilityIdentifier("messageCenter.detail.bodyLabel")

                        Spacer(minLength: 0)
                    }
                }
                .padding(DUSpacing.xl)
                .frame(maxWidth: .infinity, minHeight: 280, alignment: .topLeading)
                .background(DUTheme.panel)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(DUTheme.lineLight, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.06), radius: 20, x: 0, y: 10)
            }
            .padding(.horizontal, DUSpacing.lg)
            .padding(.vertical, DUSpacing.md)
        }
        .accessibilityIdentifier("messageCenter.detail.content")
    }

    private var detailHeader: some View {
        HStack(alignment: .center, spacing: DUSpacing.md) {
            MessageAvatarView(message: message)
                .accessibilityIdentifier("messageCenter.detail.avatar")

            HStack(alignment: .center, spacing: DUSpacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.displaySender())
                        .font(.du(20, weight: .bold))
                        .foregroundColor(DUTheme.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("messageCenter.detail.senderLabel")

                    Text(detailDateText)
                        .font(.du(14, weight: .medium))
                        .foregroundColor(DUTheme.inkTertiary)
                        .multilineTextAlignment(.leading)
                        .accessibilityIdentifier("messageCenter.detail.timeLabel")
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var detailDateText: String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "dd MMM yyyy, HH:mm"
        return formatter.string(from: message.createdAt ?? Date())
    }
}
