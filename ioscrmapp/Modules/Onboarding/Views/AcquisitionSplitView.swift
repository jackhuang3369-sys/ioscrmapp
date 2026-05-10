import SwiftUI

struct AcquisitionSplitView: View {
    @Environment(\.duTheme) private var theme
    @EnvironmentObject private var languageStore: AppLanguageStore

    let onSelectNewNumber: () -> Void
    let onSelectPortIn: () -> Void
    let onBack: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: DUSpacing.xxl) {
                    backButton

                    DUBrandMark()

                    header

                    VStack(spacing: DUSpacing.md) {
                        newNumberButton
                        portInButton
                    }
                }
                .padding(.horizontal, DUSpacing.xl)
                .padding(.top, proxy.safeAreaInsets.top + 8)
                .padding(.bottom, DUSpacing.xxxl)
            }
            .background(theme.colors.background.canvas.ignoresSafeArea())
        }
        .navigationBarBackButtonHidden(true)
    }

    private var backButton: some View {
        HStack {
            DUIconButton(
                title: nil,
                circleSize: 40,
                backgroundColor: theme.colors.surface.card,
                shadowColor: theme.components.card.elevation.color,
                shadowRadius: DUElevation.control.radius,
                shadowY: DUElevation.control.y
            ) {
                Image(systemName: "chevron.left")
                    .font(.du(.bodyLargeSemibold))
                    .foregroundColor(theme.colors.text.primary)
            } action: {
                onBack()
            }
            Spacer()
        }
    }

    private var header: some View {
        VStack(spacing: DUSpacing.sm) {
            Text(localized("entry.acquisition.title"))
                .font(.du(.headline))
                .foregroundColor(theme.colors.text.primary)
                .multilineTextAlignment(.center)
            Text(localized("entry.acquisition.subtitle"))
                .font(.du(.body))
                .foregroundColor(theme.colors.text.tertiary)
                .multilineTextAlignment(.center)
        }
    }

    private var newNumberButton: some View {
        DUButton(
            title: localized("entry.acquisition.newNumber"),
            style: .primary,
            height: 56,
            textStyle: .titleSmall,
            action: onSelectNewNumber
        )
    }

    private var portInButton: some View {
        DUButton(
            title: localized("entry.acquisition.portIn"),
            style: .secondary,
            height: 56,
            textStyle: .titleSmall,
            action: onSelectPortIn
        )
    }

    private func localized(_ key: String, arguments: [String] = []) -> String {
        languageStore.string(key, arguments: arguments)
    }
}
