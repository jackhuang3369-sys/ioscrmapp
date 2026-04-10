import SwiftUI

private enum MallProductSelectionSheetStyle {
    // 禁用态需要保留“不可选”语义，但文字不能淡到难以识别。
    static let disabledTextColor = Color(hex: 0xBEC7D5)
}

struct MallProductSelectionSheet: View {
    @EnvironmentObject private var languageStore: AppLanguageStore

    let snapshot: MallProductDetailSnapshot
    @Binding var selectedValueIDs: Set<String>
    let locale: Locale
    let language: AppLanguage
    let onPreviewImage: (MallImageSource) -> Void
    let onClose: () -> Void
    let onConfirm: () -> Void

    @State private var activeImagePreview: MallImagePreviewContext?

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: DUSpacing.xl) {
                    ForEach(snapshot.specificationGroups) { group in
                        MallProductSelectionSection(
                            snapshot: snapshot,
                            group: group,
                            selectedValueIDs: $selectedValueIDs,
                            language: language
                        )
                    }
                }
                .padding(.horizontal, DUSpacing.lg)
                .padding(.top, DUSpacing.lg)
                .padding(.bottom, DUSpacing.xxl)
            }

            Button(action: onConfirm) {
                Text(languageStore.string("mall.detail.confirm"))
                    .font(.du(15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color(hex: 0xF3204E))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, DUSpacing.lg)
            .padding(.vertical, DUSpacing.md)
        }
        .background(Color.white)
        .fullScreenCover(item: $activeImagePreview) { preview in
            MallImagePreviewScreen(
                images: preview.images,
                initialIndex: preview.initialIndex
            )
        }
    }

    @ViewBuilder
    private var header: some View {
        VStack(spacing: DUSpacing.md) {
            HStack(alignment: .top, spacing: DUSpacing.md) {
                if let currentSKU = snapshot.currentSKU(for: selectedValueIDs) {
                    Button {
                        activeImagePreview = .single(currentSKU.previewImage)
                    } label: {
                        MallImageView(
                            image: currentSKU.previewImage,
                            cornerRadius: 14
                        )
                        .frame(width: 82, height: 82)
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(snapshot.saleLabel.value(for: language))
                                .font(.du(11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .frame(height: 24)
                                .background(Color(hex: 0xFF3958))
                                .clipShape(Capsule())

                            Text(currentSKU.formattedPrice(for: locale))
                                .font(.du(28, weight: .bold))
                                .foregroundColor(Color(hex: 0xFF244E))

                            Text("AED")
                                .font(.du(11, weight: .bold))
                                .foregroundColor(Color(hex: 0xFF244E))
                        }
                        .environment(\.layoutDirection, .leftToRight)

                        Text(currentSKU.saleEndsText.value(for: language))
                            .font(.du(12, weight: .medium))
                            .foregroundColor(Color(hex: 0x6E7B92))

                        Text(snapshot.selectedSummary(for: currentSKU, language: language))
                            .font(.du(13, weight: .semibold))
                            .foregroundColor(DUTheme.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: DUSpacing.sm)

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.du(15, weight: .bold))
                        .foregroundColor(DUTheme.inkDisabled)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DUSpacing.lg)
        .padding(.top, DUSpacing.lg)
    }
}

private struct MallProductSelectionSection: View {
    let snapshot: MallProductDetailSnapshot
    let group: MallProductDetailSpecificationGroup
    @Binding var selectedValueIDs: Set<String>
    let language: AppLanguage

    private var availableValueIDs: Set<String> {
        snapshot.availableValueIDs(
            for: group.id,
            selectedValueIDs: selectedValueIDs
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DUSpacing.md) {
            Text(group.title.value(for: language))
                .font(.du(15, weight: .bold))
                .foregroundColor(DUTheme.ink)

            switch group.displayMode {
            case .chip:
                MallWrappingFlowLayout(spacing: DUSpacing.sm) {
                    ForEach(group.values) { value in
                        MallProductSelectionChip(
                            title: value.title.value(for: language),
                            isSelected: selectedValueIDs.contains(value.id),
                            isEnabled: availableValueIDs.contains(value.id)
                        ) {
                            applySelection(value.id)
                        }
                    }
                }
            case .imageTile:
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: DUSpacing.sm), count: 3),
                    spacing: DUSpacing.sm
                ) {
                    ForEach(group.values) { value in
                        MallProductSelectionImageTile(
                            image: value.image,
                            title: value.title.value(for: language),
                            swatchHex: value.swatchHex,
                            isSelected: selectedValueIDs.contains(value.id),
                            isEnabled: availableValueIDs.contains(value.id)
                        ) {
                            applySelection(value.id)
                        }
                    }
                }
            }
        }
    }

    private func applySelection(_ valueID: String) {
        let groupValueIDs = Set(group.values.map(\.id))
        var nextValueIDs = selectedValueIDs.subtracting(groupValueIDs)
        nextValueIDs.insert(valueID)

        if let matchedSKU = snapshot.currentSKU(for: nextValueIDs) {
            selectedValueIDs = Set(matchedSKU.valueIDs)
        } else {
            selectedValueIDs = nextValueIDs
        }
    }
}

private struct MallProductSelectionChip: View {
    let title: String
    let isSelected: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.du(14, weight: .semibold))
                .foregroundColor(foregroundColor)
                .padding(.horizontal, DUSpacing.md)
                .frame(height: 40)
                .background(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(borderColor, lineWidth: isSelected ? 1.5 : 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private var foregroundColor: Color {
        if isSelected {
            return Color(hex: 0xF3204E)
        }

        return isEnabled ? DUTheme.inkSecondary : MallProductSelectionSheetStyle.disabledTextColor
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color(hex: 0xFFF1F4)
        }

        return isEnabled ? Color.white : Color(hex: 0xFBFCFE)
    }

    private var borderColor: Color {
        if isSelected {
            return Color(hex: 0xFF6A82)
        }

        return isEnabled ? Color(hex: 0xE0E6EE) : Color(hex: 0xEEF2F7)
    }
}

private struct MallProductSelectionImageTile: View {
    let image: MallImageSource?
    let title: String
    let swatchHex: UInt32?
    let isSelected: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: DUSpacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(imageBackgroundColor)
                        .frame(height: 88)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(imageBorderColor, lineWidth: imageBorderWidth)
                        )

                    if let image {
                        MallImageView(
                            image: image,
                            cornerRadius: 10
                        )
                        .padding(8)
                        .opacity(imageOpacity)
                        .saturation(imageSaturation)
                    }

                    if !isEnabled {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.28))
                            .padding(1)
                    }
                }

                Text(title)
                    .font(.du(13, weight: .semibold))
                    .foregroundColor(titleColor)
                    .lineLimit(1)
            }
            .padding(8)
            .background(containerBackgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        containerBorderColor,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private var titleColor: Color {
        if isSelected {
            return Color(hex: 0x536399)
        }

        return isEnabled ? DUTheme.inkSecondary : MallProductSelectionSheetStyle.disabledTextColor
    }

    private var containerBackgroundColor: Color {
        isEnabled ? Color.white : Color(hex: 0xFCFDFE)
    }

    private var containerBorderColor: Color {
        if isSelected {
            return Color(hex: 0xFF6A82)
        }

        return isEnabled ? Color(hex: 0xE0E6EE) : Color(hex: 0xEEF2F7)
    }

    private var imageBackgroundColor: Color {
        if !isEnabled {
            return Color(hex: 0xF8FAFD)
        }

        return Color(hex: swatchHex ?? 0xF7F8FA)
    }

    private var imageBorderColor: Color {
        if isSelected {
            return Color(hex: 0x5972C9)
        }

        return isEnabled ? Color.clear : Color(hex: 0xEFF3F8)
    }

    private var imageBorderWidth: CGFloat {
        isSelected ? 2 : 1
    }

    private var imageOpacity: Double {
        isEnabled ? 1 : 0.28
    }

    private var imageSaturation: Double {
        isEnabled ? 1 : 0.15
    }
}

private struct MallWrappingFlowLayout<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        if #available(iOS 16.0, *) {
            MallWrappingLayoutView(spacing: spacing) {
                content
            }
        } else {
            VStack(alignment: .leading, spacing: spacing) {
                content
            }
        }
    }
}

@available(iOS 16.0, *)
private struct MallWrappingLayoutView<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        MallWrappingLayout(spacing: spacing) {
            content
        }
    }
}

@available(iOS 16.0, *)
private struct MallWrappingLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        layoutSize(proposal: proposal, subviews: subviews)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let maxWidth = proposal.width ?? bounds.width
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > bounds.minX + maxWidth {
                currentX = bounds.minX
                currentY += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }

    private func layoutSize(
        proposal: ProposedViewSize,
        subviews: Subviews
    ) -> CGSize {
        let maxWidth = proposal.width ?? 320
        var currentRowWidth: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentRowWidth + size.width > maxWidth, currentRowWidth > 0 {
                totalWidth = max(totalWidth, currentRowWidth - spacing)
                totalHeight += currentRowHeight + spacing
                currentRowWidth = 0
                currentRowHeight = 0
            }

            currentRowWidth += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
        }

        totalWidth = max(totalWidth, max(currentRowWidth - spacing, 0))
        totalHeight += currentRowHeight
        return CGSize(width: totalWidth, height: totalHeight)
    }
}
