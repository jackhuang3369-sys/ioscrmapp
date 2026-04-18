import SwiftUI

struct DUPhoneField: View {
    @Environment(\.duTheme) private var theme

    let title: String
    let countryCode: String
    let placeholder: String
    @Binding var text: String
    let error: String?
    let displayText: (String) -> String
    let normalizeText: (String) -> String

    private var sanitizedPhoneBinding: Binding<String> {
        Binding(
            get: { displayText(text) },
            set: { newValue in
                text = normalizeText(newValue)
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DUSpacing.sm) {
            Text(title)
                .font(.du(14, weight: .semibold))
                .foregroundColor(theme.components.field.label)

            HStack(spacing: DUSpacing.md) {
                Text(countryCode)
                    .font(.du(16, weight: .semibold))
                    .foregroundColor(theme.components.field.label)

                Rectangle()
                    .fill(theme.components.field.divider)
                    .frame(width: 1, height: 22)

                TextField(placeholder, text: sanitizedPhoneBinding)
                    .keyboardType(.numberPad)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .font(.du(16, weight: .medium))
                    .foregroundColor(theme.components.field.text)
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
