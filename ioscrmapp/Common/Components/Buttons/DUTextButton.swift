import SwiftUI

struct DUTextButton: View {
    @Environment(\.duTheme) private var theme

    let title: String
    var color: Color?
    var fontSize: CGFloat = 14
    var weight: Font.Weight = .semibold
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(.du(fontSize, weight: weight))
            .foregroundColor(color ?? theme.colors.action.primary)
            .buttonStyle(.plain)
    }
}
