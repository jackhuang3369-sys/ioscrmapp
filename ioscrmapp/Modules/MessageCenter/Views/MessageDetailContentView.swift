import SwiftUI

struct MessageDetailContentView: View {
    @Environment(\.duTheme) private var theme

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
                            .font(.du(.headline))
                            .foregroundColor(theme.colors.text.primary)
                            .multilineTextAlignment(.leading)
                            .accessibilityIdentifier("messageCenter.detail.titleLabel")

                        Text(message.detailBody(for: language))
                            .font(.du(.body))
                            .foregroundColor(theme.colors.text.secondary)
                            .multilineTextAlignment(.leading)
                            .lineSpacing(4)
                            .accessibilityIdentifier("messageCenter.detail.bodyLabel")

                        Spacer(minLength: 0)
                    }
                }
                .padding(DUSpacing.xl)
                .frame(maxWidth: .infinity, minHeight: 280, alignment: .topLeading)
                .background(theme.colors.surface.card)
                .clipShape(RoundedRectangle(cornerRadius: theme.components.card.cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.components.card.cornerRadius, style: .continuous)
                        .stroke(theme.colors.border.subtle, lineWidth: 1)
                )
                .shadow(
                    color: theme.components.card.elevation.color,
                    radius: theme.components.card.elevation.radius,
                    x: theme.components.card.elevation.x,
                    y: theme.components.card.elevation.y
                )
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
                VStack(alignment: .leading, spacing: DUSpacing.xs) {
                    Text(message.displaySender())
                        .font(.du(.title))
                        .foregroundColor(theme.colors.text.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("messageCenter.detail.senderLabel")

                    Text(detailDateText)
                        .font(.du(.bodySmall))
                        .foregroundColor(theme.colors.text.tertiary)
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
