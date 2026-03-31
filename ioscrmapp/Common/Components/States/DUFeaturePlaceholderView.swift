import SwiftUI

struct DUFeaturePlaceholderView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore

    let title: LocalizedTextValue
    let icon: String
    let message: LocalizedTextValue

    var body: some View {
        VStack(spacing: DUSpacing.lg) {
            Text(icon)
                .font(.du(48))

            Text(languageStore.string(title))
                .font(.du(24, weight: .bold))
                .foregroundColor(DUTheme.ink)

            Text(languageStore.string(message))
                .font(.du(15, weight: .medium))
                .foregroundColor(DUTheme.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, DUSpacing.xxl)
        .background(DUTheme.background.ignoresSafeArea())
    }
}
