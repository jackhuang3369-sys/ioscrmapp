import SwiftUI
import UIKit

struct WeatherHourlyStrip: View {
    let points: [WeatherHourlyStripPoint]
    let selectedID: String
    let onSelect: (WeatherHourlyStripPoint, Bool) -> Void
    let onDragStateChange: (Bool) -> Void

    private let hapticPlayer = WeatherStripHapticPlayer.shared
    @State private var lastFeedbackIndex: Int?
    @State private var isDragging = false

    var body: some View {
        GeometryReader { proxy in
            hourlyStripContent(in: proxy.size)
        }
        .frame(height: 102)
        .onAppear {
            if lastFeedbackIndex == nil {
                lastFeedbackIndex = points.firstIndex(where: { $0.id == selectedID })
            }
            hapticPlayer.prepare()
            onDragStateChange(false)
        }
    }

    private func hourlyStripContent(in size: CGSize) -> some View {
        let layout = WeatherHourlyStripLayout(
            size: size,
            points: points,
            selectedID: selectedID
        )

        return VStack(spacing: 6) {
            stripChart(layout: layout)
            tickRow(layout: layout)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func stripChart(layout: WeatherHourlyStripLayout) -> some View {
        ZStack(alignment: .topLeading) {
            railView(layout: layout)

            if let sunriseIndex = layout.sunriseIndex {
                solarSplitLegend(
                    marker: .sunrise,
                    x: xBoundaryPosition(
                        for: sunriseIndex,
                        itemWidth: layout.itemWidth,
                        sidePadding: layout.sidePadding,
                        endCapWidth: layout.endCapWidth
                    ),
                    y: layout.idleBubbleY
                )
            }

            if let sunsetIndex = layout.sunsetIndex {
                solarSplitLegend(
                    marker: .sunset,
                    x: xBoundaryPosition(
                        for: sunsetIndex,
                        itemWidth: layout.itemWidth,
                        sidePadding: layout.sidePadding,
                        endCapWidth: layout.endCapWidth
                    ),
                    y: layout.idleBubbleY
                )
            }

            overlayContent(layout: layout)
        }
        .frame(height: layout.topOverlayHeight + layout.railHeight)
        .contentShape(Rectangle())
        .gesture(dragGesture(layout: layout))
    }

    private func railView(layout: WeatherHourlyStripLayout) -> some View {
        HStack(spacing: 0) {
            endCap(
                color: points.first.map {
                    barColor(for: $0, range: layout.range, isFocused: layout.focusedIndex == 0)
                } ?? Color.black.opacity(0.12),
                width: layout.endCapWidth,
                diameter: layout.endCapDiameter,
                height: layout.railHeight,
                maxBarTopExtension: layout.maxBarTopExtension,
                alignment: .leading
            )

            HStack(spacing: 0) {
                ForEach(Array(points.indices), id: \.self) { index in
                    barSegment(index: index, layout: layout)
                }
            }
            .frame(
                width: layout.coreWidth,
                height: layout.railHeight + layout.maxBarTopExtension,
                alignment: .bottom
            )
            .animation(.easeOut(duration: 0.10), value: isDragging)
            .transaction { transaction in
                if isDragging {
                    transaction.animation = nil
                }
            }

            endCap(
                color: points.last.map {
                    barColor(for: $0, range: layout.range, isFocused: layout.focusedIndex == points.count - 1)
                } ?? Color.black.opacity(0.12),
                width: layout.endCapWidth,
                diameter: layout.endCapDiameter,
                height: layout.railHeight,
                maxBarTopExtension: layout.maxBarTopExtension,
                alignment: .trailing
            )
        }
        .frame(
            width: layout.contentWidth,
            height: layout.railHeight + layout.maxBarTopExtension,
            alignment: .bottom
        )
        .offset(x: layout.sidePadding, y: layout.topOverlayHeight - layout.maxBarTopExtension)
    }

    private func barSegment(index: Int, layout: WeatherHourlyStripLayout) -> some View {
        let point = points[index]
        let topExtension = WeatherHourlyStripCore.barTopExtension(
            index: index,
            focusedIndex: layout.focusedIndex,
            isDragging: isDragging
        )

        return Rectangle()
            .fill(barColor(for: point, range: layout.range, isFocused: index == layout.focusedIndex))
            .frame(width: layout.itemWidth, height: layout.railHeight + topExtension)
            .frame(
                width: layout.itemWidth,
                height: layout.railHeight + layout.maxBarTopExtension,
                alignment: .bottom
            )
            .contentShape(Rectangle())
            .onTapGesture {
                selectPoint(at: index, isDragSelection: false)
            }
    }

    private func endCap(
        color: Color,
        width: CGFloat,
        diameter: CGFloat,
        height: CGFloat,
        maxBarTopExtension: CGFloat,
        alignment: Alignment
    ) -> some View {
        Circle()
            .fill(color)
            .frame(width: diameter, height: height)
            .frame(width: width, alignment: alignment)
            .frame(height: height + maxBarTopExtension, alignment: .bottom)
            .clipped()
    }

    @ViewBuilder
    private func overlayContent(layout: WeatherHourlyStripLayout) -> some View {
        if isDragging, points.indices.contains(layout.focusedIndex) {
            timeBubble(
                text: WeatherHourlyStripCore.bubbleText(hour24: points[layout.focusedIndex].hour24),
                x: layout.focusedX,
                y: layout.bubbleY,
                diameter: layout.bubbleDiameter
            )
        } else {
            temperatureLabel(
                text: "\(layout.range.high)",
                x: xPosition(
                    for: layout.highIndex,
                    itemWidth: layout.itemWidth,
                    sidePadding: layout.sidePadding,
                    endCapWidth: layout.endCapWidth
                ),
                y: layout.idleBubbleY
            )

            if layout.lowIndex != layout.highIndex {
                temperatureLabel(
                    text: "\(layout.range.low)",
                    x: xPosition(
                        for: layout.lowIndex,
                        itemWidth: layout.itemWidth,
                        sidePadding: layout.sidePadding,
                        endCapWidth: layout.endCapWidth
                    ),
                    y: layout.idleBubbleY
                )
            }
        }
    }

    private func dragGesture(layout: WeatherHourlyStripLayout) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isDragging {
                    hapticPlayer.prepare()
                    onDragStateChange(true)
                }
                isDragging = true
                let localX = min(max(value.location.x - layout.coreStartX, 0), layout.coreWidth)
                let index = WeatherHourlyStripCore.focusedIndex(
                    forLocationX: localX,
                    itemWidth: layout.itemWidth,
                    count: points.count
                )
                selectPoint(at: index, isDragSelection: true)
            }
            .onEnded { _ in
                withAnimation(.easeOut(duration: 0.18)) {
                    isDragging = false
                }
                onDragStateChange(false)
            }
    }

    private func tickRow(layout: WeatherHourlyStripLayout) -> some View {
        HStack(spacing: 0) {
            ForEach(tickIndices(), id: \.self) { index in
                Text(tickLabel(for: index))
                    .font(.du(9, weight: .medium))
                    .foregroundColor(Color.black.opacity(0.52))
                    .frame(width: layout.contentWidth / 8)
            }
        }
        .frame(width: layout.contentWidth, alignment: .leading)
        .padding(.leading, layout.sidePadding)
    }

    private func tickIndices() -> [Int] {
        stride(from: 0, to: min(points.count, 24), by: 3).map { $0 }
    }

    private func tickLabel(for index: Int) -> String {
        guard points.indices.contains(index) else { return "" }
        return index == 0 ? "NOW" : "\(points[index].hour24)"
    }

    private func barColor(for point: WeatherHourlyStripPoint, range: WeatherHourlyTemperatureRange, isFocused: Bool) -> Color {
        let palette: [Color] = [
            Color(hex: 0xF6F6F6),
            Color(hex: 0xE9E9E9),
            Color(hex: 0xDEDEDE),
            Color(hex: 0xD2D2D2),
            Color(hex: 0xC7C7C7)
        ]
        let normalized = WeatherHourlyStripCore.normalizedTemperatureValue(
            temperature: point.temperature,
            minTemperature: range.low,
            maxTemperature: range.high
        )
        let bucket = min(max(Int(round(normalized * Double(palette.count - 1))), 0), palette.count - 1)
        let baseColor = palette[bucket]

        if isFocused && isDragging {
            return palette[min(bucket + 1, palette.count - 1)].opacity(0.96)
        }

        return baseColor
    }

    private func xPosition(for index: Int, itemWidth: CGFloat, sidePadding: CGFloat, endCapWidth: CGFloat) -> CGFloat {
        sidePadding + endCapWidth + itemWidth * CGFloat(index) + itemWidth / 2
    }

    private func xBoundaryPosition(for index: Int, itemWidth: CGFloat, sidePadding: CGFloat, endCapWidth: CGFloat) -> CGFloat {
        sidePadding + endCapWidth + itemWidth * CGFloat(index)
    }

    private func timeBubble(text: String, x: CGFloat, y: CGFloat, diameter: CGFloat) -> some View {
        Circle()
            .fill(Color.black.opacity(0.16))
            .frame(width: diameter, height: diameter)
            .overlay {
                Text(text)
                    .font(neumaticCompressedFont(size: 19.5, fallbackWeight: .bold))
                    .foregroundColor(Color.black.opacity(0.74))
            }
            .position(x: x, y: y)
            .animation(.spring(response: 0.22, dampingFraction: 0.84), value: selectedID)
    }

    private func temperatureLabel(text: String, x: CGFloat, y: CGFloat) -> some View {
        Text(text)
            .font(neumaticCompressedFont(size: 28.5, fallbackWeight: .semibold))
            .tracking(1.2)
            .fixedSize(horizontal: true, vertical: false)
            .allowsTightening(false)
            .scaleEffect(x: 1.2, y: 1.0, anchor: .center)
            .foregroundColor(Color.black.opacity(0.78))
            .shadow(color: .white.opacity(0.24), radius: 1, x: 0, y: 0)
            .position(x: x, y: y)
            .animation(.spring(response: 0.22, dampingFraction: 0.84), value: selectedID)
    }

    private func condensedNumberFont(size: CGFloat, weight: UIFont.Weight) -> Font {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        let descriptor = base.fontDescriptor.withSymbolicTraits(.traitCondensed) ?? base.fontDescriptor
        let condensed = UIFont(descriptor: descriptor, size: size)
        return Font(condensed)
    }

    private func neumaticCompressedFont(size: CGFloat, fallbackWeight: UIFont.Weight) -> Font {
        if let neumatic = UIFont(name: "Neumatic Compressed", size: size) {
            return Font(neumatic)
        }
        if let neumaticPS = UIFont(name: "NeumaticCompressed", size: size) {
            return Font(neumaticPS)
        }
        return condensedNumberFont(size: size, weight: fallbackWeight)
    }

    private func solarSplitLegend(marker: WeatherSolarMarker, x: CGFloat, y: CGFloat) -> some View {
        let leftColor: Color
        let rightColor: Color

        switch marker {
        case .sunrise:
            leftColor = Color.black.opacity(0.86)
            rightColor = Color.white.opacity(0.94)
        case .sunset:
            leftColor = Color.white.opacity(0.94)
            rightColor = Color.black.opacity(0.86)
        }

        return HStack(spacing: 0) {
            Rectangle().fill(leftColor)
            Rectangle().fill(rightColor)
        }
        .frame(width: 13, height: 13)
        .clipShape(Circle())
        .shadow(color: .black.opacity(0.04), radius: 1.0, x: 0, y: 0.3)
            .position(x: x, y: y)
    }

    private func selectPoint(at index: Int, isDragSelection: Bool) {
        guard points.indices.contains(index) else { return }
        let point = points[index]
        let previousIndex = lastFeedbackIndex

        if WeatherHourlyStripCore.shouldTriggerFeedback(
            previousFocusedIndex: previousIndex,
            nextFocusedIndex: index
        ) {
            hapticPlayer.tick()
            WeatherAudioPlayer.shared.playTimelineScrollTick()
        }

        lastFeedbackIndex = index
        onSelect(point, isDragSelection)
    }
}

private final class WeatherStripHapticPlayer {
    static let shared = WeatherStripHapticPlayer()

    private let generator = UISelectionFeedbackGenerator()

    private init() {}

    func prepare() {
        generator.prepare()
    }

    func tick() {
        generator.selectionChanged()
        generator.prepare()
    }
}

private struct WeatherHourlyStripLayout {
    let sidePadding: CGFloat = 10
    let endCapDiameter: CGFloat = 34
    let railHeight: CGFloat = 34
    let topOverlayHeight: CGFloat = 24
    let bubbleDiameter: CGFloat = 44
    let maxBarTopExtension: CGFloat = 18

    let totalWidth: CGFloat
    let contentWidth: CGFloat
    let endCapWidth: CGFloat
    let coreWidth: CGFloat
    let itemWidth: CGFloat
    let focusedIndex: Int
    let focusedX: CGFloat
    let groupedTemperatures: [Int]
    let range: WeatherHourlyTemperatureRange
    let bubbleY: CGFloat
    let idleBubbleY: CGFloat
    let labelY: CGFloat
    let highIndex: Int
    let lowIndex: Int
    let sunriseIndex: Int?
    let sunsetIndex: Int?
    let coreStartX: CGFloat

    init(size: CGSize, points: [WeatherHourlyStripPoint], selectedID: String) {
        totalWidth = size.width
        contentWidth = size.width - sidePadding * 2
        endCapWidth = endCapDiameter / 2
        coreWidth = max(0, contentWidth - endCapWidth * 2)

        let itemCount = max(points.count, 1)
        itemWidth = coreWidth / CGFloat(itemCount)
        focusedIndex = points.firstIndex(where: { $0.id == selectedID }) ?? 0
        focusedX = sidePadding + endCapWidth + itemWidth * CGFloat(focusedIndex) + itemWidth / 2
        groupedTemperatures = WeatherHourlyStripCore.groupedTemperatures(points, blockSize: 3)
        range = WeatherHourlyStripCore.temperatureRange(points)
        // Keep the drag bubble clear of the time/temperature rows by lifting it
        // above the rail a bit more than the resting labels.
        bubbleY = topOverlayHeight - 42
        idleBubbleY = topOverlayHeight + railHeight / 2
        labelY = topOverlayHeight + railHeight / 2
        highIndex = points.indices.max(by: { points[$0].temperature < points[$1].temperature }) ?? 0
        lowIndex = points.indices.min(by: { points[$0].temperature < points[$1].temperature }) ?? 0
        sunriseIndex = points.firstIndex(where: { $0.hour24 == 6 })
        sunsetIndex = points.firstIndex(where: { $0.hour24 == 18 })
        coreStartX = sidePadding + endCapWidth
    }
}
