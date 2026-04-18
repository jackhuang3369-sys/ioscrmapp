import SwiftUI

struct DUTextButton: View {
    @Environment(\.duTheme) private var theme

    let title: String
    var color: Color?
    var fontSize: CGFloat = 14
    var weight: Font.Weight = .semibold
    var textStyle: DUTextStyle? = nil
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(textStyle.map(Font.du) ?? .du(fontSize, weight: weight))
            .foregroundColor(color ?? theme.colors.action.primary)
            .buttonStyle(.plain)
    }
}
