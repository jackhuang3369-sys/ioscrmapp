import SwiftUI

struct LanguageSettingsView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var languageStore: AppLanguageStore

    @State private var selectedLanguage: AppLanguage = .fallback

    var body: some View {
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
                presentationMode.wrappedValue.dismiss()
            }

            Spacer()
        }
        .padding(DUSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(DUTheme.background.ignoresSafeArea())
        .navigationTitle(languageStore.string("language.settings.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedLanguage = languageStore.currentLanguage
        }
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
