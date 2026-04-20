import SwiftUI

enum MallTheme {
    static let headerGradient = DUTheme.brandGradient
}

struct MallPalette {
    let theme: DUTheme

    var canvasBackground: Color { theme.colors.background.canvas }
    var panelBackground: Color { theme.colors.surface.card }
    var raisedBackground: Color { theme.colors.surface.raised }
    var imageChromeFill: Color { theme.colors.surface.card.opacity(theme.resolvedColorScheme == .dark ? 0.24 : 0.76) }
    var chipBackground: Color { theme.colors.background.secondary }
    var chipBorder: Color { theme.colors.border.default }
    var chipSelectedBackground: Color { theme.colors.brand.primaryBackground }
    var promoText: Color { theme.colors.status.warning }
    var promoBackground: Color { theme.colors.status.warningBackground }
    var priceAccent: Color { theme.colors.brand.magenta }
    var accent: Color { theme.colors.brand.secondary }
    var accentSoft: Color { theme.colors.brand.primaryBackground }
    var inverseText: Color { theme.colors.text.inverse }
    var primaryText: Color { theme.colors.text.primary }
    var secondaryText: Color { theme.colors.text.secondary }
    var tertiaryText: Color { theme.colors.text.tertiary }
    var disabledText: Color { theme.colors.text.disabled }
    var subtleBorder: Color { theme.colors.border.subtle }
    var defaultBorder: Color { theme.colors.border.default }
    var cardElevation: DUElevationStyle { theme.components.card.elevation }
    var liftedElevation: DUElevationStyle { DUElevation.lifted }
    var spotlightElevation: DUElevationStyle { DUElevation.spotlight }

    func badgeGradient(for style: MallProductBadgeStyle) -> LinearGradient {
        switch style {
        case .sale:
            return LinearGradient(
                colors: [theme.colors.status.error, theme.colors.brand.magenta],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .brand:
            return LinearGradient(
                colors: [theme.colors.text.primary, theme.colors.brand.secondary],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .featured:
            return LinearGradient(
                colors: [theme.colors.status.warning, theme.colors.brand.magenta],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}

struct MallBottomActionBarMetrics {
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    let reservedHeight: CGFloat
    let verticalOffset: CGFloat
}

enum MallBottomActionBarLayout {
    // 商城页底栏顶部统一保留轻微留白，避免按钮主体显得过厚。
    static let topPadding: CGFloat = 6
    // 有 Home Indicator 时不再额外撑高底部，让底栏真正压进安全区。
    static let bottomPaddingWithSafeArea: CGFloat = 0
    // 无 Home Indicator 设备保留最小缓冲，避免按钮视觉上贴边。
    static let bottomPaddingWithoutSafeArea: CGFloat = 10

    static func metrics(
        buttonHeight: CGFloat,
        bottomSafeInset: CGFloat
    ) -> MallBottomActionBarMetrics {
        let resolvedBottomPadding: CGFloat
        if bottomSafeInset > 0 {
            resolvedBottomPadding = bottomPaddingWithSafeArea
        } else {
            resolvedBottomPadding = bottomPaddingWithoutSafeArea
        }

        let resolvedVerticalOffset: CGFloat
        if bottomSafeInset > 0 {
            // 与商品详情页一致：让整条底栏继续压进 Home Indicator 区域。
            resolvedVerticalOffset = bottomSafeInset * 0.55
        } else {
            resolvedVerticalOffset = 0
        }

        return MallBottomActionBarMetrics(
            topPadding: topPadding,
            bottomPadding: resolvedBottomPadding,
            reservedHeight: topPadding + buttonHeight + resolvedBottomPadding,
            verticalOffset: resolvedVerticalOffset
        )
    }
}

struct MallImageView: View {
    @Environment(\.duTheme) private var theme

    let image: MallImageSource
    var cornerRadius: CGFloat = 18
    var cropsBitmapToFill: Bool = false
    var bitmapFillScale: CGFloat = 1

    var body: some View {
        switch image {
        case let .asset(name):
            bitmapView(
                Image(name)
                    .renderingMode(.original)
            )
        case let .system(name, backgroundHex, tintHex):
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(hex: backgroundHex))
                .overlay(
                    Image(systemName: name)
                        .font(.du(28, weight: .semibold))
                        .foregroundColor(Color(hex: tintHex))
                )
        case let .remote(url):
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image):
                    bitmapView(image)
                default:
                    remotePlaceholder
                }
            }
        }
    }

    @ViewBuilder
    private func bitmapView(_ image: Image) -> some View {
        if cropsBitmapToFill {
            // 商品卡片、分类入口这类固定容器优先铺满显示，保持画面块面完整。
            image
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scaleEffect(bitmapFillScale)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            image
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(DUSpacing.md)
                .background(MallPalette(theme: theme).imageChromeFill)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }

    private var remotePlaceholder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(MallPalette(theme: theme).chipBackground)
            .overlay(
                Image(systemName: "photo")
                    .font(.du(.title))
                    .foregroundColor(MallPalette(theme: theme).tertiaryText)
            )
    }
}

struct MallSearchBarView: View {
    @Environment(\.duTheme) private var theme
    @EnvironmentObject private var languageStore: AppLanguageStore

    @Binding var text: String
    let placeholder: String
    let submitTitle: String
    let onBack: () -> Void
    let onSubmit: () -> Void

    var body: some View {
        let palette = MallPalette(theme: theme)

        HStack(spacing: DUSpacing.md) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.du(.titleSmallStrong))
                    .foregroundColor(palette.inverseText)
            }
            .buttonStyle(.plain)

            HStack(spacing: DUSpacing.sm) {
                Text(languageStore.string("home.tab.mall"))
                    .font(.du(.metaEmphasized))
                    .foregroundColor(palette.secondaryText)
                    .padding(.trailing, DUSpacing.sm)
                    .overlay(alignment: .trailing) {
                        Rectangle()
                            .fill(palette.defaultBorder)
                            .frame(width: 1, height: 14)
                    }

                HStack(spacing: DUSpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.du(.bodyStrong))
                        .foregroundColor(palette.tertiaryText)

                    TextField(placeholder, text: $text)
                        .font(.du(.label))
                        .foregroundColor(palette.primaryText)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)

                    if !text.isEmpty {
                        Button {
                            text = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.du(.bodyStrong))
                                .foregroundColor(palette.disabledText)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DUSpacing.md)
                .frame(height: 34)
                .background(palette.chipBackground)
                .clipShape(Capsule())
            }
            .padding(.horizontal, DUSpacing.md)
            .frame(height: 46)
            .background(palette.panelBackground.opacity(theme.resolvedColorScheme == .dark ? 0.88 : 0.96))
            .clipShape(RoundedRectangle(cornerRadius: DURadius.control, style: .continuous))
            .shadow(
                color: palette.liftedElevation.color,
                radius: palette.liftedElevation.radius,
                x: palette.liftedElevation.x,
                y: palette.liftedElevation.y
            )

            Button(submitTitle, action: onSubmit)
                .font(.du(.bodyEmphasized))
                .foregroundColor(palette.inverseText)
                .buttonStyle(.plain)
        }
    }
}

struct MallProductCard: View {
    @Environment(\.duTheme) private var theme
    @EnvironmentObject private var languageStore: AppLanguageStore

    private let imageAreaHeight: CGFloat = 162
    private let imageAreaCornerRadius: CGFloat = 18

    let product: MallProduct
    let action: () -> Void

    var body: some View {
        let palette = MallPalette(theme: theme)

        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    MallImageView(
                        image: product.coverImage,
                        cornerRadius: imageAreaCornerRadius,
                        cropsBitmapToFill: true,
                        bitmapFillScale: 1.03
                    )

                    Text(product.resolvedBadge(for: languageStore.currentLanguage))
                        .font(.du(.tinyEmphasized))
                        .foregroundColor(palette.inverseText)
                        .padding(.horizontal, DUSpacing.base)
                        .frame(height: 24)
                        .background(badgeBackground)
                        .clipShape(Capsule())
                        .padding(DUSpacing.md)
                }
                .frame(height: imageAreaHeight)
                .clipShape(RoundedRectangle(cornerRadius: imageAreaCornerRadius, style: .continuous))

                VStack(alignment: .leading, spacing: DUSpacing.sm) {
                    Text(product.resolvedTitle(for: languageStore.currentLanguage))
                        .font(.du(.labelStrong))
                        .foregroundColor(palette.primaryText)
                        .lineLimit(2)

                    Text(product.resolvedSubtitle(for: languageStore.currentLanguage))
                        .font(.du(.caption))
                        .foregroundColor(palette.secondaryText)
                        .lineLimit(2)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DUSpacing.smd) {
                            ForEach(product.resolvedTags(for: languageStore.currentLanguage), id: \.self) { tag in
                                Text(tag)
                                    .font(.du(.tinyEmphasized))
                                    .foregroundColor(palette.promoText)
                                    .padding(.horizontal, DUSpacing.sm)
                                    .frame(height: 22)
                                    .background(palette.promoBackground)
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("AED")
                            .font(.du(.tinyEmphasized))
                            .foregroundColor(palette.priceAccent)

                        Text(product.formattedPrice(for: languageStore.locale))
                            .font(.du(.titleStrong))
                            .foregroundColor(palette.priceAccent)

                        if let originalPrice = product.formattedOriginalPrice(for: languageStore.locale) {
                            Text("AED \(originalPrice)")
                                .font(.du(.caption))
                                .foregroundColor(palette.disabledText)
                                .strikethrough()
                                .padding(.leading, DUSpacing.xs)
                        }
                    }
                    .environment(\.layoutDirection, .leftToRight)

                    HStack {
                        Text(product.salesText(for: languageStore.currentLanguage))
                            .font(.du(.caption))
                            .foregroundColor(palette.tertiaryText)

                        Spacer()

                        Circle()
                            .fill(palette.badgeGradient(for: .sale))
                            .frame(width: 30, height: 30)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.du(.bodyEmphasized))
                                    .foregroundColor(palette.inverseText)
                            )
                    }
                }
                .padding(.horizontal, DUSpacing.md)
                .padding(.top, DUSpacing.md)
                .padding(.bottom, DUSpacing.lg)
            }
            .background(palette.panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: DURadius.sheet, style: .continuous))
            .shadow(
                color: palette.cardElevation.color,
                radius: palette.cardElevation.radius,
                x: palette.cardElevation.x,
                y: palette.cardElevation.y
            )
        }
        .buttonStyle(.plain)
    }

    private var badgeBackground: LinearGradient {
        MallPalette(theme: theme).badgeGradient(for: product.badge.style)
    }
}

struct MallProductFeedGrid: View {
    let products: [MallProduct]
    var columnSpacing: CGFloat = DUSpacing.md
    var rowSpacing: CGFloat = DUSpacing.md
    var oddItemTopPadding: CGFloat = DUSpacing.lg
    let onSelectProduct: (MallProduct) -> Void

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: columnSpacing),
                GridItem(.flexible(), spacing: columnSpacing),
            ],
            spacing: rowSpacing
        ) {
            ForEach(products.indices, id: \.self) { index in
                let product = products[index]
                MallProductCard(product: product) {
                    onSelectProduct(product)
                }
                .padding(.top, index.isMultiple(of: 2) ? 0 : oddItemTopPadding)
            }
        }
    }
}

private enum MallLoadMoreTriggerDefaults {
    static let activationDistance: CGFloat = 24
    static let preloadDistance: CGFloat = 220
}

struct MallScrollActivationTrigger: View {
    let coordinateSpaceName: String
    var activationDistance: CGFloat = MallLoadMoreTriggerDefaults.activationDistance
    let isArmed: Bool
    let onActivate: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let hasPassedThreshold = proxy.frame(in: .named(coordinateSpaceName)).minY <= -activationDistance

            Color.clear
                .frame(height: 1)
                .task(id: ActivationState(isArmed: isArmed, hasPassedThreshold: hasPassedThreshold)) {
                    if !isArmed, hasPassedThreshold {
                        onActivate()
                    }
                }
        }
        .frame(height: 1)
    }

    private struct ActivationState: Equatable {
        let isArmed: Bool
        let hasPassedThreshold: Bool
    }
}

struct MallScrollLoadMoreTrigger: View {
    let coordinateSpaceName: String
    let viewportHeight: CGFloat
    let isArmed: Bool
    let canTrigger: Bool
    var preloadDistance: CGFloat = MallLoadMoreTriggerDefaults.preloadDistance
    let onTrigger: () -> Void

    @State private var hasTriggeredInsideThreshold = false

    var body: some View {
        GeometryReader { proxy in
            let isWithinThreshold = proxy.frame(in: .named(coordinateSpaceName)).minY
                <= viewportHeight + preloadDistance

            Color.clear
                .frame(height: 1)
                .task(id: TriggerState(
                    isArmed: isArmed,
                    canTrigger: canTrigger,
                    isWithinThreshold: isWithinThreshold
                )) {
                    if !isArmed || !isWithinThreshold {
                        hasTriggeredInsideThreshold = false
                        return
                    }

                    guard canTrigger, !hasTriggeredInsideThreshold else {
                        return
                    }

                    hasTriggeredInsideThreshold = true
                    onTrigger()
                }
        }
        .frame(height: 1)
    }

    private struct TriggerState: Equatable {
        let isArmed: Bool
        let canTrigger: Bool
        let isWithinThreshold: Bool
    }
}

struct MallProductFeedLoadMoreFooter: View {
    @Environment(\.duTheme) private var theme
    @EnvironmentObject private var languageStore: AppLanguageStore

    let isLoading: Bool
    let errorMessage: LocalizedTextValue?
    let retryTint: Color
    let onRetry: () -> Void

    var body: some View {
        if isLoading {
            HStack(spacing: DUSpacing.sm) {
                ProgressView()
                Text(languageStore.string("mall.state.loading.title"))
                    .font(.du(.meta))
                    .foregroundColor(MallPalette(theme: theme).secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DUSpacing.md)
        } else if let errorMessage {
            VStack(spacing: DUSpacing.sm) {
                Text(languageStore.string(errorMessage))
                    .font(.du(.meta))
                    .foregroundColor(MallPalette(theme: theme).secondaryText)
                    .multilineTextAlignment(.center)

                Button(action: onRetry) {
                    Text(languageStore.string("common.retry"))
                        .font(.du(.metaEmphasized))
                        .foregroundColor(retryTint)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, DUSpacing.sm)
        }
    }
}

struct MallProductTargetSheet: View {
    @Environment(\.duTheme) private var theme
    @EnvironmentObject private var languageStore: AppLanguageStore
    @Environment(\.dismiss) private var dismiss

    let product: MallProduct

    var body: some View {
        let palette = MallPalette(theme: theme)

        ScrollView(showsIndicators: false) {
            VStack(spacing: DUSpacing.xl) {
                MallImageView(image: product.coverImage, cornerRadius: 28)
                    .frame(width: 150, height: 150)

                VStack(spacing: DUSpacing.sm) {
                    Text(languageStore.string("mall.detail.title"))
                        .font(.du(.titleStrong))
                        .foregroundColor(palette.primaryText)

                    Text(product.resolvedTitle(for: languageStore.currentLanguage))
                        .font(.du(.bodyLargeSemibold))
                        .foregroundColor(palette.secondaryText)
                        .multilineTextAlignment(.center)

                    Text(
                        languageStore.string(
                            "mall.detail.subtitle",
                            arguments: [product.detailTarget]
                        )
                    )
                    .font(.du(.label))
                    .foregroundColor(palette.tertiaryText)
                    .multilineTextAlignment(.center)
                }

                if !product.detailMediaList.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DUSpacing.md) {
                            ForEach(product.detailMediaList) { media in
                                Link(destination: media.url) {
                                    MallProductDetailMediaCard(media: media)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }

                DUButton(
                    title: languageStore.string("common.ok"),
                    style: .primary
                ) {
                    dismiss()
                }
            }
        }
        .padding(DUSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.panelBackground.ignoresSafeArea())
    }
}

private struct MallProductDetailMediaCard: View {
    @Environment(\.duTheme) private var theme

    let media: MallProductDetailMedia

    var body: some View {
        ZStack {
            switch media.type {
            case .image:
                AsyncImage(url: media.url) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        placeholder
                    }
                }
            case .video:
                LinearGradient(
                    colors: [MallPalette(theme: theme).primaryText, MallPalette(theme: theme).accent],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay(
                    Image(systemName: "play.circle.fill")
                        .font(.du(.hero))
                        .foregroundColor(MallPalette(theme: theme).inverseText)
                )
            }
        }
        .frame(width: 120, height: 120)
        .clipShape(RoundedRectangle(cornerRadius: DURadius.cardLarge, style: .continuous))
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: DURadius.cardLarge, style: .continuous)
            .fill(MallPalette(theme: theme).chipBackground)
            .overlay(
                Image(systemName: "photo")
                    .font(.du(.headline))
                    .foregroundColor(MallPalette(theme: theme).tertiaryText)
            )
    }
}
