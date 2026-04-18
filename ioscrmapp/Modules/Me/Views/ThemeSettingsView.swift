import SwiftUI

struct ThemeSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.duTheme) private var theme
    @EnvironmentObject private var languageStore: AppLanguageStore
    @EnvironmentObject private var themeStore: AppThemeStore

    @State private var selectedMode: DUThemeMode = .system

    var body: some View {
        VStack(spacing: 0) {
            header

            VStack(spacing: DUSpacing.xl) {
                VStack(alignment: .leading, spacing: DUSpacing.sm) {
                    Text(languageStore.string("theme.settings.subtitle"))
                        .font(.du(15, weight: .medium))
                        .foregroundColor(theme.colors.text.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(languageStore.string("theme.settings.current"))
                        .font(.du(12, weight: .semibold))
                        .foregroundColor(theme.colors.text.tertiary)

                    Text(languageStore.string(themeStore.currentMode.displayNameKey))
                        .font(.du(15, weight: .bold))
                        .foregroundColor(theme.colors.text.primary)
                }

                VStack(spacing: DUSpacing.md) {
                    ForEach(DUThemeMode.allCases) { mode in
                        DUListItem(
                            title: languageStore.string(mode.displayNameKey),
                            subtitle: languageStore.string(mode.descriptionKey),
                            accessory: .selection(isSelected: selectedMode == mode)
                        ) {
                            selectedMode = mode
                        }
                        .duCardStyle()
                        .accessibilityIdentifier("themeSettings.mode.\(mode.rawValue)")
                    }
                }

                DUButton(
                    title: languageStore.string("theme.settings.save"),
                    style: .primary
                ) {
                    themeStore.updateThemeMode(selectedMode)
                    dismiss()
                }
                .accessibilityIdentifier("themeSettings.saveButton")

                Spacer()
            }
            .padding(DUSpacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(theme.colors.background.canvas.ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear {
            selectedMode = themeStore.currentMode
        }
    }

    private var header: some View {
        HStack(spacing: DUSpacing.md) {
            Button(action: { dismiss() }) {
                HStack(spacing: DUSpacing.sm) {
                    Image(systemName: "chevron.backward")
                        .font(.du(15, weight: .bold))
                    Text(languageStore.string("common.back"))
                        .font(.du(15, weight: .semibold))
                }
                .foregroundColor(theme.colors.text.primary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("themeSettings.backButton")

            Spacer()

            Text(languageStore.string("theme.settings.title"))
                .font(.du(20, weight: .bold))
                .foregroundColor(theme.colors.text.primary)
                .multilineTextAlignment(.center)
                .lineLimit(1)

            Spacer()

            Color.clear
                .frame(width: 82, height: 32)
        }
        .padding(.horizontal, DUSpacing.lg)
        .padding(.top, DUSpacing.md)
        .padding(.bottom, DUSpacing.md)
        .background(theme.colors.surface.card)
    }
}

struct ThemeSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            preview(language: .english, themeMode: .light)
                .previewDisplayName("Light EN")
            preview(language: .arabic, themeMode: .dark)
                .environment(\.layoutDirection, .rightToLeft)
                .previewDisplayName("Dark AR")
        }
    }

    private static func preview(language: AppLanguage, themeMode: DUThemeMode) -> some View {
        NavigationView {
            ThemeSettingsView()
        }
        .environmentObject(AppLanguageStore(initialLanguage: language))
        .environmentObject(AppThemeStore(initialMode: themeMode))
        .duTheme(mode: themeMode)
    }
}
