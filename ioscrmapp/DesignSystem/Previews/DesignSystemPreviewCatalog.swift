import SwiftUI

struct DesignSystemPreviewCatalog: View {
    @Environment(\.duTheme) private var theme
    @EnvironmentObject private var languageStore: AppLanguageStore
    @State private var text = "hello@du.ae"
    @State private var phone = "521234567"
    @State private var selected = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DUSpacing.xl) {
                Text(languageStore.string("theme.settings.title"))
                    .font(.du(24, weight: .bold))

                DUSectionCard(title: "Buttons") {
                    VStack(spacing: DUSpacing.md) {
                        DUButton(title: "Primary", style: .primary) {}
                        DUButton(title: "Secondary", style: .secondary) {}
                        DUButton(title: "Danger", style: .danger) {}
                    }
                }

                DUSectionCard(title: "Fields") {
                    VStack(spacing: DUSpacing.lg) {
                        DUTextField(
                            title: "Email",
                            placeholder: "hello@du.ae",
                            text: $text,
                            error: nil,
                            keyboardType: .emailAddress
                        )
                        DUPhoneField(
                            title: "Phone",
                            countryCode: "+971",
                            placeholder: "52 123 4567",
                            text: $phone,
                            error: nil,
                            displayText: { $0 },
                            normalizeText: { $0.filter(\.isNumber) }
                        )
                    }
                }

                DUSectionCard(title: "List") {
                    VStack(spacing: 0) {
                        DUListItem(title: "Theme", subtitle: "System, Light, Dark", accessory: .selection(isSelected: selected)) {
                            selected.toggle()
                        }
                        Divider()
                        DUListItem(title: "Status", subtitle: "Badge example", accessory: .badge("New")) {}
                    }
                }

                DUStateView(
                    systemImage: "checkmark.seal.fill",
                    iconColor: theme.colors.action.primary,
                    title: "Ready",
                    subtitle: "Core components consume semantic tokens."
                )
                .frame(height: 260)
            }
            .padding(DUSpacing.xl)
        }
        .duSurfaceStyle(.canvas)
    }
}

struct DesignSystemPreviewCatalog_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            preview(language: .english, mode: .light)
                .previewDisplayName("Light EN")
            preview(language: .english, mode: .dark)
                .previewDisplayName("Dark EN")
            preview(language: .arabic, mode: .dark)
                .environment(\.layoutDirection, .rightToLeft)
                .previewDisplayName("Dark AR RTL")
        }
    }

    private static func preview(language: AppLanguage, mode: DUThemeMode) -> some View {
        DesignSystemPreviewCatalog()
            .environmentObject(AppLanguageStore(initialLanguage: language))
            .environmentObject(AppThemeStore(initialMode: mode))
            .duTheme(mode: mode)
    }
}
