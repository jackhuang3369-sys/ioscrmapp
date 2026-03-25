import SwiftUI

enum MallTheme {
    static let headerGradient = DUTheme.brandGradient
}

struct MallImageView: View {
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
                .padding(12)
                .background(Color.white.opacity(0.76))
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }

    private var remotePlaceholder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(hex: 0xEEF4FA))
            .overlay(
                Image(systemName: "photo")
                    .font(.du(24, weight: .semibold))
                    .foregroundColor(Color(hex: 0x7B8CA8))
            )
    }
}

struct MallSearchBarView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore

    @Binding var text: String
    let placeholder: String
    let submitTitle: String
    let onBack: () -> Void
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: DUSpacing.md) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.du(18, weight: .bold))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)

            HStack(spacing: DUSpacing.sm) {
                Text(languageStore.string("home.tab.mall"))
                    .font(.du(12, weight: .bold))
                    .foregroundColor(DUTheme.inkSecondary)
                    .padding(.trailing, DUSpacing.sm)
                    .overlay(alignment: .trailing) {
                        Rectangle()
                            .fill(DUTheme.line)
                            .frame(width: 1, height: 14)
                    }

                HStack(spacing: DUSpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.du(14, weight: .semibold))
                        .foregroundColor(DUTheme.inkTertiary)

                    TextField(placeholder, text: $text)
                        .font(.du(13, weight: .medium))
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)

                    if !text.isEmpty {
                        Button {
                            text = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.du(14, weight: .semibold))
                                .foregroundColor(DUTheme.inkDisabled)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DUSpacing.md)
                .frame(height: 34)
                .background(Color(hex: 0xEEF2F7))
                .clipShape(Capsule())
            }
            .padding(.horizontal, DUSpacing.md)
            .frame(height: 46)
            .background(Color.white.opacity(0.96))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 8)

            Button(submitTitle, action: onSubmit)
                .font(.du(14, weight: .bold))
                .foregroundColor(.white)
                .buttonStyle(.plain)
        }
    }
}

struct MallProductCard: View {
    @EnvironmentObject private var languageStore: AppLanguageStore

    private let imageAreaHeight: CGFloat = 162
    private let imageAreaCornerRadius: CGFloat = 18

    let product: MallProduct
    let action: () -> Void

    var body: some View {
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
                        .font(.du(10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .frame(height: 24)
                        .background(badgeBackground)
                        .clipShape(Capsule())
                        .padding(12)
                }
                .frame(height: imageAreaHeight)
                .clipShape(RoundedRectangle(cornerRadius: imageAreaCornerRadius, style: .continuous))

                VStack(alignment: .leading, spacing: DUSpacing.sm) {
                    Text(product.resolvedTitle(for: languageStore.currentLanguage))
                        .font(.du(13, weight: .semibold))
                        .foregroundColor(DUTheme.ink)
                        .lineLimit(2)

                    Text(product.resolvedSubtitle(for: languageStore.currentLanguage))
                        .font(.du(11, weight: .medium))
                        .foregroundColor(DUTheme.inkSecondary)
                        .lineLimit(2)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(product.resolvedTags(for: languageStore.currentLanguage), id: \.self) { tag in
                                Text(tag)
                                    .font(.du(10, weight: .bold))
                                    .foregroundColor(Color(hex: 0xC86C00))
                                    .padding(.horizontal, 8)
                                    .frame(height: 22)
                                    .background(Color(hex: 0xFFF2DC))
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("AED")
                            .font(.du(10, weight: .bold))
                            .foregroundColor(Color(hex: 0xFF445D))

                        Text(product.formattedPrice(for: languageStore.locale))
                            .font(.du(22, weight: .bold))
                            .foregroundColor(Color(hex: 0xFF445D))

                        if let originalPrice = product.formattedOriginalPrice(for: languageStore.locale) {
                            Text("AED \(originalPrice)")
                                .font(.du(11, weight: .medium))
                                .foregroundColor(DUTheme.inkDisabled)
                                .strikethrough()
                                .padding(.leading, 4)
                        }
                    }
                    .environment(\.layoutDirection, .leftToRight)

                    HStack {
                        Text(product.salesText(for: languageStore.currentLanguage))
                            .font(.du(11, weight: .medium))
                            .foregroundColor(DUTheme.inkTertiary)

                        Spacer()

                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: 0xFF6674), Color(hex: 0xFF8E68)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 30, height: 30)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.du(14, weight: .bold))
                                    .foregroundColor(.white)
                            )
                    }
                }
                .padding(.horizontal, DUSpacing.md)
                .padding(.top, DUSpacing.md)
                .padding(.bottom, DUSpacing.lg)
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 10)
        }
        .buttonStyle(.plain)
    }

    private var badgeBackground: LinearGradient {
        switch product.badge.style {
        case .sale:
            return LinearGradient(
                colors: [Color(hex: 0xFF5968), Color(hex: 0xFF8B67)],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .brand:
            return LinearGradient(
                colors: [Color(hex: 0x1B2430), Color(hex: 0x314257)],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .featured:
            return LinearGradient(
                colors: [Color(hex: 0xFF8A00), Color(hex: 0xF97316)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}

struct MallProductTargetSheet: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    @Environment(\.dismiss) private var dismiss

    let product: MallProduct

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: DUSpacing.xl) {
                MallImageView(image: product.coverImage, cornerRadius: 28)
                    .frame(width: 150, height: 150)

                VStack(spacing: DUSpacing.sm) {
                    Text(languageStore.string("mall.detail.title"))
                        .font(.du(22, weight: .bold))
                        .foregroundColor(DUTheme.ink)

                    Text(product.resolvedTitle(for: languageStore.currentLanguage))
                        .font(.du(16, weight: .semibold))
                        .foregroundColor(DUTheme.inkSecondary)
                        .multilineTextAlignment(.center)

                    Text(
                        languageStore.string(
                            "mall.detail.subtitle",
                            arguments: [product.detailTarget]
                        )
                    )
                    .font(.du(13, weight: .medium))
                    .foregroundColor(DUTheme.inkTertiary)
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
        .background(Color.white.ignoresSafeArea())
    }
}

private struct MallProductDetailMediaCard: View {
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
                    colors: [Color(hex: 0x1B2430), Color(hex: 0x314257)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay(
                    Image(systemName: "play.circle.fill")
                        .font(.du(30, weight: .semibold))
                        .foregroundColor(.white)
                )
            }
        }
        .frame(width: 120, height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color(hex: 0xEEF4FA))
            .overlay(
                Image(systemName: "photo")
                    .font(.du(20, weight: .semibold))
                    .foregroundColor(Color(hex: 0x7B8CA8))
            )
    }
}
