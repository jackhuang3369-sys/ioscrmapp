import SwiftUI

private struct DUFieldShellModifier: ViewModifier {
    @Environment(\.duTheme) private var theme
    let isError: Bool

    func body(content: Content) -> some View {
        let field = theme.components.field
        content
            .padding(.horizontal, DUSpacing.lg)
            .frame(height: field.height)
            .background(
                RoundedRectangle(cornerRadius: field.cornerRadius, style: .continuous)
                    .fill(field.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: field.cornerRadius, style: .continuous)
                    .stroke(isError ? field.errorBorder : field.border, lineWidth: 1.2)
            )
            .clipShape(RoundedRectangle(cornerRadius: field.cornerRadius, style: .continuous))
    }
}

extension View {
    func duFieldShell(isError: Bool) -> some View {
        modifier(DUFieldShellModifier(isError: isError))
    }
}
