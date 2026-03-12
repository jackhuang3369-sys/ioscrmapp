import SwiftUI

struct DUSectionCard<Content: View>: View {
    let title: String?
    let trailingTitle: String?
    var spacing: CGFloat = DUSpacing.lg
    var horizontalPadding: CGFloat = DUSpacing.lg
    var verticalPadding: CGFloat = DUSpacing.lg
    var trailingAction: (() -> Void)? = nil
    @ViewBuilder let content: () -> Content

    init(
        title: String? = nil,
        trailingTitle: String? = nil,
        spacing: CGFloat = DUSpacing.lg,
        horizontalPadding: CGFloat = DUSpacing.lg,
        verticalPadding: CGFloat = DUSpacing.lg,
        trailingAction: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.trailingTitle = trailingTitle
        self.spacing = spacing
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.trailingAction = trailingAction
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            if let title {
                HStack {
                    Text(title)
                        .font(.du(17, weight: .bold))
                        .foregroundColor(DUTheme.ink)

                    Spacer()

                    if let trailingTitle, let trailingAction {
                        DUTextButton(
                            title: trailingTitle,
                            fontSize: 12,
                            weight: .semibold,
                            action: trailingAction
                        )
                    }
                }
            }

            content()
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .duCardStyle()
    }
}
