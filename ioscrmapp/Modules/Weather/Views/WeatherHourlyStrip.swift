import SwiftUI
import UIKit

struct WeatherHourlyStrip: View {
    let points: [WeatherHourlyStripPoint]
    let selectedID: String
    let usesDarkTheme: Bool
    let onSelect: (WeatherHourlyStripPoint, Bool) -> Void
    let onBubbleStateChange: (WeatherHourlyBubbleState) -> Void

    private let hapticPlayer = WeatherStripHapticPlayer.shared
    @State private var lastFeedbackIndex: Int?
    @State private var isDragging = false
    @State private var dragLocationX: CGFloat = 0
    @State private var previousDragLocationX: CGFloat = 0
    @State private var dragDirectionSign: CGFloat = 0

    init(
        points: [WeatherHourlyStripPoint],
        selectedID: String,
        usesDarkTheme: Bool = false,
        onSelect: @escaping (WeatherHourlyStripPoint, Bool) -> Void,
        onBubbleStateChange: @escaping (WeatherHourlyBubbleState) -> Void = { _ in }
    ) {
        self.points = points
        self.selectedID = selectedID
        self.usesDarkTheme = usesDarkTheme
        self.onSelect = onSelect
        self.onBubbleStateChange = onBubbleStateChange
    }

    var body: some View {
        GeometryReader { proxy in
            let sidePadding: CGFloat = 10
            let rawContentWidth = proxy.size.width - sidePadding * 2
            let contentWidth = rawContentWidth.isFinite ? max(0, rawContentWidth) : 0
            let endCapDiameter: CGFloat = 34
            let endCapWidth: CGFloat = endCapDiameter / 2
            let railHeight: CGFloat = 34
            let topOverlayHeight: CGFloat = 32
            let bubbleDiameter: CGFloat = 49
            let maxBarTopExtension: CGFloat = 9
            let dragStateAnimation = Animation.easeOut(duration: 0.10)

            let coreWidth = max(0, contentWidth - endCapWidth * 2)
            let itemCount = max(points.count, 1)
            let itemWidth = coreWidth / CGFloat(itemCount)
            let selectedFocusedIndex = points.firstIndex(where: { $0.id == selectedID }) ?? 0
            let dragFocusedIndex = WeatherHourlyStripCore.focusedIndex(
                forLocationX: dragLocationX,
                itemWidth: itemWidth,
                count: points.count
            )
            let focusedIndex = isDragging ? dragFocusedIndex : selectedFocusedIndex
            let focusedPosition = itemWidth > 0
                ? min(max(dragLocationX / itemWidth, 0), CGFloat(points.count - 1))
                : CGFloat(focusedIndex)
            let focusedX = WeatherHourlyStripCore.bubbleCenterX(
                sidePadding: sidePadding,
                endCapWidth: endCapWidth,
                itemWidth: itemWidth,
                focusedPosition: focusedPosition
            )
            let range = WeatherHourlyStripCore.temperatureRange(points)
            let focusedTopExtension = isDragging ? maxBarTopExtension : 0
            let bubbleY = WeatherHourlyStripCore.bubbleCenterY(
                topOverlayHeight: topOverlayHeight,
                focusedTopExtension: focusedTopExtension,
                bubbleDiameter: bubbleDiameter,
                offsetAboveTop: 5
            )
            let leftEndCapColor = points.first.map {
                barColor(for: $0, range: range, isFocused: focusedIndex == 0)
            } ?? fallbackBarColor
            let rightEndCapColor = points.last.map {
                barColor(for: $0, range: range, isFocused: focusedIndex == points.count - 1)
            } ?? fallbackBarColor

            let highIndex = points.indices.max(by: { points[$0].temperature < points[$1].temperature }) ?? 0
            let lowIndex = points.indices.min(by: { points[$0].temperature < points[$1].temperature }) ?? 0
            let idleBubbleY = topOverlayHeight + railHeight / 2
            let sunriseX = solarMarkerX(
                marker: .sunrise,
                itemWidth: itemWidth,
                sidePadding: sidePadding,
                endCapWidth: endCapWidth
            )
            let sunsetX = solarMarkerX(
                marker: .sunset,
                itemWidth: itemWidth,
                sidePadding: sidePadding,
                endCapWidth: endCapWidth
            )

            VStack(spacing: 6) {
                ZStack(alignment: .topLeading) {
                    HStack(spacing: 0) {
                        Circle()
                            .fill(leftEndCapColor)
                            .frame(width: endCapDiameter, height: railHeight)
                            .frame(width: endCapWidth, alignment: .leading)
                            .frame(height: railHeight + maxBarTopExtension, alignment: .bottom)
                            .clipped()

                        HStack(spacing: 0) {
                            ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                                let topExtension = topExtension(
                                    for: index,
                                    focusedPosition: focusedPosition,
                                    directionSign: dragDirectionSign,
                                    isDragging: isDragging
                                )

                                Rectangle()
                                    .fill(barColor(for: point, range: range, isFocused: index == focusedIndex))
                                    .frame(width: itemWidth, height: railHeight + topExtension)
                                    .frame(width: itemWidth, height: railHeight + maxBarTopExtension, alignment: .bottom)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectPoint(at: index, isDragSelection: false)
                                    }
                            }
                        }
                        .frame(width: coreWidth, height: railHeight + maxBarTopExtension, alignment: .bottom)
                        .animation(dragStateAnimation, value: isDragging)
                        .transaction { transaction in
                            if isDragging {
                                transaction.animation = nil
                            }
                        }

                        Circle()
                            .fill(rightEndCapColor)
                            .frame(width: endCapDiameter, height: railHeight)
                            .frame(width: endCapWidth, alignment: .trailing)
                            .frame(height: railHeight + maxBarTopExtension, alignment: .bottom)
                            .clipped()
                    }
                    .frame(width: contentWidth, height: railHeight + maxBarTopExtension, alignment: .bottom)
                    .offset(x: sidePadding, y: topOverlayHeight - maxBarTopExtension)

                    if let sunriseX {
                        solarSplitLegend(
                            marker: .sunrise,
                            x: sunriseX,
                            y: idleBubbleY
                        )
                    }

                    if let sunsetX {
                        solarSplitLegend(
                            marker: .sunset,
                            x: sunsetX,
                            y: idleBubbleY
                        )
                    }

                    if isDragging, points.indices.contains(focusedIndex) {
                        timeBubble(
                            text: WeatherHourlyStripCore.bubbleText(hour24: points[focusedIndex].hour24),
                            x: focusedX,
                            y: bubbleY,
                            diameter: bubbleDiameter
                        )
                    } else {
                        temperatureLabel(
                            text: "\(range.high)",
                            x: xPosition(for: highIndex, itemWidth: itemWidth, sidePadding: sidePadding, endCapWidth: endCapWidth),
                            y: idleBubbleY
                        )

                        if lowIndex != highIndex {
                            temperatureLabel(
                                text: "\(range.low)",
                                x: xPosition(for: lowIndex, itemWidth: itemWidth, sidePadding: sidePadding, endCapWidth: endCapWidth),
                                y: idleBubbleY
                            )
                        }
                    }
                }
                .frame(height: topOverlayHeight + railHeight)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let coreStartX = sidePadding + endCapWidth
                            let localX = min(max(value.location.x - coreStartX, 0), coreWidth)
                            dragLocationX = localX

                            if !isDragging {
                                hapticPlayer.prepare()
                                previousDragLocationX = value.location.x
                            }

                            isDragging = true

                            let deltaX = value.location.x - previousDragLocationX
                            if abs(deltaX) > 0.4 {
                                dragDirectionSign = deltaX > 0 ? 1 : -1
                            }
                            previousDragLocationX = value.location.x
                            let index = WeatherHourlyStripCore.focusedIndex(
                                forLocationX: localX,
                                itemWidth: itemWidth,
                                count: points.count
                            )
                            let dragBubbleCenterY = WeatherHourlyStripCore.bubbleCenterY(
                                topOverlayHeight: topOverlayHeight,
                                focusedTopExtension: maxBarTopExtension,
                                bubbleDiameter: bubbleDiameter,
                                offsetAboveTop: 5
                            )
                            let dragBubbleTopY = dragBubbleCenterY - bubbleDiameter / 2
                            onBubbleStateChange(WeatherHourlyBubbleState(isVisible: true, bubbleTopY: dragBubbleTopY))
                            selectPoint(at: index, isDragSelection: true)
                        }
                        .onEnded { _ in
                            withAnimation(.easeOut(duration: 0.18)) {
                                isDragging = false
                                dragDirectionSign = 0
                            }
                            onBubbleStateChange(WeatherHourlyBubbleState(isVisible: false, bubbleTopY: 0))
                        }
                )

                HStack(spacing: 0) {
                    ForEach(tickIndices(), id: \.self) { index in
                        Text(tickLabel(for: index))
                            .font(.du(9, weight: .medium))
                            .foregroundColor(tickLabelColor)
                            .frame(width: contentWidth / 8)
                    }
                }
                .frame(width: contentWidth, alignment: .leading)
                .padding(.leading, sidePadding)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 102)
        .onAppear {
            if lastFeedbackIndex == nil {
                lastFeedbackIndex = points.firstIndex(where: { $0.id == selectedID })
            }
            let initialIndex = points.firstIndex(where: { $0.id == selectedID }) ?? 0
            dragLocationX = CGFloat(initialIndex)
            hapticPlayer.prepare()
            onBubbleStateChange(WeatherHourlyBubbleState(isVisible: false, bubbleTopY: 0))
        }
    }

    private func topExtension(for index: Int, focusedPosition: CGFloat, directionSign: CGFloat, isDragging: Bool) -> CGFloat {
        WeatherHourlyStripCore.directionalTopExtension(
            index: index,
            focusedPosition: focusedPosition,
            directionSign: directionSign,
            isDragging: isDragging,
            maxExtension: 9
        )
    }

    private func tickIndices() -> [Int] {
        stride(from: 0, to: min(points.count, 24), by: 3).map { $0 }
    }

    private func tickLabel(for index: Int) -> String {
        guard points.indices.contains(index) else { return "" }
        return index == 0 ? "NOW" : "\(points[index].hour24)"
    }

    private var fallbackBarColor: Color {
        usesDarkTheme ? Color.white.opacity(0.18) : Color.black.opacity(0.12)
    }

    private var tickLabelColor: Color {
        usesDarkTheme ? Color.white.opacity(0.64) : Color.black.opacity(0.52)
    }

    private func barColor(for point: WeatherHourlyStripPoint, range: WeatherHourlyTemperatureRange, isFocused: Bool) -> Color {
        let palette: [UInt32] = [0xF6F6F6, 0xE9E9E9, 0xDEDEDE, 0xD2D2D2, 0xC7C7C7]
        let normalized = WeatherHourlyStripCore.normalizedTemperatureValue(
            temperature: point.temperature,
            minTemperature: range.low,
            maxTemperature: range.high
        )
        let liftedNormalized = isFocused && isDragging ? min(normalized + 0.08, 1) : normalized
        return interpolatedPaletteColor(hexStops: palette, normalized: liftedNormalized)
    }

    private func xPosition(for index: Int, itemWidth: CGFloat, sidePadding: CGFloat, endCapWidth: CGFloat) -> CGFloat {
        sidePadding + endCapWidth + itemWidth * CGFloat(index) + itemWidth / 2
    }

    private func xBoundaryPosition(for index: Int, itemWidth: CGFloat, sidePadding: CGFloat, endCapWidth: CGFloat) -> CGFloat {
        sidePadding + endCapWidth + itemWidth * CGFloat(index)
    }

    private func solarMarkerX(
        marker: WeatherSolarMarker,
        itemWidth: CGFloat,
        sidePadding: CGFloat,
        endCapWidth: CGFloat
    ) -> CGFloat? {
        let time = WeatherHourlyStripCore.solarMarkerTime(marker)
        guard let index = points.firstIndex(where: { $0.hour24 == time.hour24 }) else {
            return nil
        }

        let hourProgress = min(max(CGFloat(time.minute) / 60, 0), 1)
        return xBoundaryPosition(
            for: index,
            itemWidth: itemWidth,
            sidePadding: sidePadding,
            endCapWidth: endCapWidth
        ) + itemWidth * hourProgress
    }

    private func interpolatedPaletteColor(hexStops: [UInt32], normalized: Double) -> Color {
        guard let first = hexStops.first else {
            return Color.white
        }
        guard hexStops.count > 1 else {
            return Color(hex: first)
        }

        let clamped = min(max(normalized, 0), 1)
        let scaled = clamped * Double(hexStops.count - 1)
        let lowerIndex = min(max(Int(floor(scaled)), 0), hexStops.count - 1)
        let upperIndex = min(lowerIndex + 1, hexStops.count - 1)
        let progress = scaled - Double(lowerIndex)
        return interpolatedColor(from: hexStops[lowerIndex], to: hexStops[upperIndex], progress: progress)
    }

    private func interpolatedColor(from startHex: UInt32, to endHex: UInt32, progress: Double) -> Color {
        let start = rgbComponents(from: startHex)
        let end = rgbComponents(from: endHex)
        let clamped = min(max(progress, 0), 1)

        return Color(
            red: start.red + (end.red - start.red) * clamped,
            green: start.green + (end.green - start.green) * clamped,
            blue: start.blue + (end.blue - start.blue) * clamped
        )
    }

    private func rgbComponents(from hex: UInt32) -> (red: Double, green: Double, blue: Double) {
        (
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    private func timeBubble(text: String, x: CGFloat, y: CGFloat, diameter: CGFloat) -> some View {
        Circle()
            .fill(timeBubbleFill)
            .frame(width: diameter, height: diameter)
            .overlay {
                Text(text)
                    .font(neumaticCompressedWideBoldFont(size: 27))
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                    .foregroundColor(timeBubbleTextColor)
                    .padding(.horizontal, 5)
            }
            .shadow(color: timeBubbleShadowColor, radius: 10, x: 0, y: 4)
            .position(x: x, y: y)
    }

    private func temperatureLabel(text: String, x: CGFloat, y: CGFloat) -> some View {
        Text(text)
            .font(neumaticCompressedFont(size: 28.5, fallbackWeight: .semibold))
            .tracking(1.2)
            .fixedSize(horizontal: true, vertical: false)
            .allowsTightening(false)
            .scaleEffect(x: 1.2, y: 1.0, anchor: .center)
            .foregroundColor(Color.black.opacity(0.78))
            .shadow(color: temperatureLabelShadowColor, radius: 1, x: 0, y: 0)
            .position(x: x, y: y)
            .animation(.spring(response: 0.22, dampingFraction: 0.84), value: selectedID)
    }

    private var timeBubbleFill: Color {
        usesDarkTheme ? Color.white.opacity(0.18) : Color.black.opacity(0.16)
    }

    private var timeBubbleTextColor: Color {
        usesDarkTheme ? Color.white.opacity(0.96) : Color.black
    }

    private var timeBubbleShadowColor: Color {
        usesDarkTheme ? Color.black.opacity(0.26) : Color.clear
    }

    private var temperatureLabelShadowColor: Color {
        usesDarkTheme ? Color.white.opacity(0.34) : Color.white.opacity(0.24)
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

    private func neumaticCompressedWideBoldFont(size: CGFloat) -> Font {
        let preferredFontNames = [
            "Neumatic Compressed SemiBold",
            "NeumaticCompressed-SemiBold",
            "Neumatic Compressed Medium",
            "NeumaticCompressed-Medium",
            "Neumatic Compressed Demi",
            "NeumaticCompressed-Demi"
        ]

        for name in preferredFontNames {
            if let font = UIFont(name: name, size: size) {
                return Font(font)
            }
        }

        return neumaticCompressedFont(size: size, fallbackWeight: .black)
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
            if isDragSelection {
                WeatherAudioPlayer.shared.playTimelineScrollTick()
            } else {
                WeatherAudioPlayer.shared.playDaySelect()
            }
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
