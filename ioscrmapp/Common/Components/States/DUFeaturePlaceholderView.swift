import SwiftUI

struct DUFeaturePlaceholderView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    @Environment(\.duTheme) private var theme

    let title: LocalizedTextValue
    let icon: String
    let message: LocalizedTextValue

    var body: some View {
        VStack(spacing: DUSpacing.lg) {
            Text(icon)
                .font(.du(48))

            Text(languageStore.string(title))
                .font(.du(24, weight: .bold))
                .foregroundColor(theme.colors.text.primary)

            Text(languageStore.string(message))
                .font(.du(15, weight: .medium))
                .foregroundColor(theme.colors.text.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, DUSpacing.xxl)
        .background(theme.colors.background.canvas.ignoresSafeArea())
    }
}
