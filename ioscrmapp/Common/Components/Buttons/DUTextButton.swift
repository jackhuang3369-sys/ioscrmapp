import SwiftUI

struct DUTextButton: View {
    let title: String
    var color: Color = DUTheme.cyan
    var fontSize: CGFloat = 14
    var weight: Font.Weight = .semibold
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(.du(fontSize, weight: weight))
            .foregroundColor(color)
            .buttonStyle(.plain)
    }
}
