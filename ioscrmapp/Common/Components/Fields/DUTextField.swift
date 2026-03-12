import SwiftUI

struct DUTextField: View {
    let title: String?
    let placeholder: String
    @Binding var text: String
    let error: String?
    var keyboardType: UIKeyboardType = .default
    var isSecure = false

    @State private var isSecureRevealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: DUSpacing.sm) {
            if let title {
                Text(title)
                    .font(.du(14, weight: .semibold))
                    .foregroundColor(DUTheme.inkSecondary)
            }

            HStack(spacing: DUSpacing.sm) {
                Group {
                    if isSecure, !isSecureRevealed {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                            .keyboardType(keyboardType)
                    }
                }
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .font(.du(16, weight: .medium))
                .foregroundColor(DUTheme.ink)

                if isSecure {
                    Button {
                        isSecureRevealed.toggle()
                    } label: {
                        Image(systemName: isSecureRevealed ? "eye.slash" : "eye")
                            .foregroundColor(DUTheme.inkTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DUSpacing.lg)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(DUTheme.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(error == nil ? DUTheme.line : DUTheme.error, lineWidth: 1.2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            if let error {
                Text(error)
                    .font(.du(12, weight: .medium))
                    .foregroundColor(DUTheme.error)
            }
        }
    }
}
