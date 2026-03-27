import SwiftUI

struct LanguageSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageStore: AppLanguageStore

    @State private var selectedLanguage: AppLanguage = .fallback

    var body: some View {
        VStack(spacing: 0) {
            header

            VStack(spacing: DUSpacing.xl) {
                VStack(alignment: .leading, spacing: DUSpacing.sm) {
                    Text(languageStore.string("language.settings.subtitle"))
                        .font(.du(15, weight: .medium))
                        .foregroundColor(DUTheme.inkSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(languageStore.string("language.settings.current"))
                        .font(.du(12, weight: .semibold))
                        .foregroundColor(DUTheme.inkTertiary)

                    Text(languageStore.string(languageStore.currentLanguage.displayNameKey))
                        .font(.du(15, weight: .bold))
                        .foregroundColor(DUTheme.ink)
                }

                VStack(spacing: DUSpacing.md) {
                    ForEach(AppLanguage.allCases) { language in
                        DUListItem(
                            title: language.nativeName,
                            subtitle: languageStore.string(language.displayNameKey),
                            accessory: .selection(isSelected: selectedLanguage == language)
                        ) {
                            selectedLanguage = language
                        }
                        .duCardStyle()
                    }
                }

                DUButton(
                    title: languageStore.string("language.settings.save"),
                    style: .primary
                ) {
                    languageStore.updateLanguage(selectedLanguage)
                    dismiss()
                }

                Spacer()
            }
            .padding(DUSpacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(DUTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear {
            selectedLanguage = languageStore.currentLanguage
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
                .foregroundColor(DUTheme.ink)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("languageSettings.backButton")

            Spacer()

            Text(languageStore.string("language.settings.title"))
                .font(.du(20, weight: .bold))
                .foregroundColor(DUTheme.ink)
                .multilineTextAlignment(.center)
                .lineLimit(1)

            Spacer()

            Color.clear
                .frame(width: 82, height: 32)
        }
        .padding(.horizontal, DUSpacing.lg)
        .padding(.top, DUSpacing.md)
        .padding(.bottom, DUSpacing.md)
        .background(DUTheme.panel)
    }
}

struct LanguageSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LanguageSettingsView()
        }
        .environmentObject(AppLanguageStore(initialLanguage: .english))
    }
}
