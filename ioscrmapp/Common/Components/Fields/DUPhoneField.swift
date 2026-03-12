import SwiftUI

struct DUPhoneField: View {
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
                .foregroundColor(DUTheme.inkSecondary)

            HStack(spacing: DUSpacing.md) {
                Text(countryCode)
                    .font(.du(16, weight: .semibold))
                    .foregroundColor(DUTheme.inkSecondary)

                Rectangle()
                    .fill(DUTheme.lineLight)
                    .frame(width: 1, height: 22)

                TextField(placeholder, text: sanitizedPhoneBinding)
                    .keyboardType(.numberPad)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .font(.du(16, weight: .medium))
                    .foregroundColor(DUTheme.ink)
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
