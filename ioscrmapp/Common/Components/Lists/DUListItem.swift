import SwiftUI

enum DUListItemLeading: Sendable {
    case asset(String)
}

enum DUListItemAccessory: Sendable {
    case none
    case chevron
    case badge(String)
    case selection(isSelected: Bool)
}

struct DUListItem: View {
    let title: String
    let subtitle: String?
    let leading: DUListItemLeading?
    let accessory: DUListItemAccessory
    let action: () -> Void

    init(
        title: String,
        subtitle: String? = nil,
        leading: DUListItemLeading? = nil,
        accessory: DUListItemAccessory = .chevron,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leading = leading
        self.accessory = accessory
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: DUSpacing.md) {
                if let leading {
                    leadingView(leading)
                }

                VStack(alignment: .leading, spacing: subtitle == nil ? 0 : DUSpacing.xs) {
                    Text(title)
                        .font(.du(15, weight: .semibold))
                        .foregroundColor(DUTheme.ink)

                    if let subtitle {
                        Text(subtitle)
                            .font(.du(12, weight: .medium))
                            .foregroundColor(DUTheme.inkTertiary)
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer()

                accessoryView(accessory)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DUSpacing.lg)
            .padding(.vertical, DUSpacing.lg)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func leadingView(_ leading: DUListItemLeading) -> some View {
        switch leading {
        case let .asset(assetName):
            Image(assetName)
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 38, height: 38)
        }
    }

    @ViewBuilder
    private func accessoryView(_ accessory: DUListItemAccessory) -> some View {
        switch accessory {
        case .none:
            EmptyView()
        case .chevron:
            Image(systemName: "chevron.forward")
                .font(.du(12, weight: .bold))
                .foregroundColor(DUTheme.inkDisabled)
        case let .badge(text):
            Text(text)
                .font(.du(10, weight: .bold))
                .foregroundColor(DUTheme.warning)
                .padding(.horizontal, DUSpacing.sm)
                .frame(height: 22)
                .background(DUTheme.warningBackground)
                .clipShape(Capsule())
        case let .selection(isSelected):
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.du(20, weight: .semibold))
                .foregroundColor(isSelected ? DUTheme.cyan : DUTheme.inkDisabled)
        }
    }
}
