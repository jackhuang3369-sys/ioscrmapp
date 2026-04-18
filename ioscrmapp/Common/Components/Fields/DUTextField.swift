import SwiftUI

struct DUTextField: View {
    @Environment(\.duTheme) private var theme

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
                    .foregroundColor(theme.components.field.label)
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
                .foregroundColor(theme.components.field.text)

                if isSecure {
                    Button {
                        isSecureRevealed.toggle()
                    } label: {
                        Image(systemName: isSecureRevealed ? "eye.slash" : "eye")
                            .foregroundColor(theme.components.field.placeholder)
                    }
                    .buttonStyle(.plain)
                }
            }
            .duFieldShell(isError: error != nil)

            if let error {
                Text(error)
                    .font(.du(12, weight: .medium))
                    .foregroundColor(theme.components.field.errorText)
            }
        }
    }
}
