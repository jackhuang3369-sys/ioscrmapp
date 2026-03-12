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
                    Button {
                        selectedLanguage = language
                    } label: {
                        HStack(spacing: DUSpacing.md) {
                            VStack(alignment: .leading, spacing: DUSpacing.xs) {
                                Text(language.nativeName)
                                    .font(.du(16, weight: .bold))
                                    .foregroundColor(DUTheme.ink)

                                Text(languageStore.string(language.displayNameKey))
                                    .font(.du(12, weight: .medium))
                                    .foregroundColor(DUTheme.inkSecondary)
                            }

                            Spacer()

                            Image(systemName: selectedLanguage == language ? "checkmark.circle.fill" : "circle")
                                .font(.du(20, weight: .semibold))
                                .foregroundColor(selectedLanguage == language ? DUTheme.cyan : DUTheme.inkDisabled)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, DUSpacing.lg)
                        .padding(.vertical, DUSpacing.lg)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .duCardStyle()
                }
            }

            Button {
                languageStore.updateLanguage(selectedLanguage)
                presentationMode.wrappedValue.dismiss()
            } label: {
                Text(languageStore.string("language.settings.save"))
                    .font(.du(16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(DUTheme.brandGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)

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
