import SwiftUI
import UIKit

struct WeatherHourlyStrip: View {
    let points: [WeatherHourlyStripPoint]
    let selectedID: String
    let onSelect: (WeatherHourlyStripPoint, Bool) -> Void

    private let hapticPlayer = WeatherStripHapticPlayer.shared
    @State private var lastFeedbackIndex: Int?
    @State private var isDragging = false

    var body: some View {
        GeometryReader { proxy in
            let sidePadding: CGFloat = 10
            let contentWidth = proxy.size.width - sidePadding * 2
            let endCapDiameter: CGFloat = 34
            let endCapWidth: CGFloat = endCapDiameter / 2
            let railHeight: CGFloat = 34
            let topOverlayHeight: CGFloat = 32
            let bubbleDiameter: CGFloat = 44
            let maxBarTopExtension: CGFloat = 18
            let dragFocusAnimation = Animation.linear(duration: 0.05)
            let dragStateAnimation = Animation.easeOut(duration: 0.10)

            let coreWidth = max(0, contentWidth - endCapWidth * 2)
            let itemCount = max(points.count, 1)
            let itemWidth = coreWidth / CGFloat(itemCount)
            let focusedIndex = points.firstIndex(where: { $0.id == selectedID }) ?? 0
            let focusedX = sidePadding + endCapWidth + itemWidth * CGFloat(focusedIndex) + itemWidth / 2
            let range = WeatherHourlyStripCore.temperatureRange(points)
            let bubbleY = max(bubbleDiameter / 2, topOverlayHeight - 10)
            let leftEndCapColor = points.first.map {
                barColor(for: $0, range: range, isFocused: focusedIndex == 0)
            } ?? Color.black.opacity(0.12)
            let rightEndCapColor = points.last.map {
                barColor(for: $0, range: range, isFocused: focusedIndex == points.count - 1)
            } ?? Color.black.opacity(0.12)

            let highIndex = points.indices.max(by: { points[$0].temperature < points[$1].temperature }) ?? 0
            let lowIndex = points.indices.min(by: { points[$0].temperature < points[$1].temperature }) ?? 0
            let idleBubbleY = topOverlayHeight + railHeight / 2
            let sunriseIndex = points.firstIndex(where: { $0.hour24 == 6 })
            let sunsetIndex = points.firstIndex(where: { $0.hour24 == 18 })

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
                                let topExtension = WeatherHourlyStripCore.barTopExtension(
                                    index: index,
                                    focusedIndex: focusedIndex,
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

                    if let sunriseIndex {
                        solarSplitLegend(
                            marker: .sunrise,
                            x: xBoundaryPosition(for: sunriseIndex, itemWidth: itemWidth, sidePadding: sidePadding, endCapWidth: endCapWidth),
                            y: idleBubbleY
                        )
                    }

                    if let sunsetIndex {
                        solarSplitLegend(
                            marker: .sunset,
                            x: xBoundaryPosition(for: sunsetIndex, itemWidth: itemWidth, sidePadding: sidePadding, endCapWidth: endCapWidth),
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
                            if !isDragging {
                                hapticPlayer.prepare()
                            }
                            isDragging = true
                            let coreStartX = sidePadding + endCapWidth
                            let localX = min(max(value.location.x - coreStartX, 0), coreWidth)
                            let index = WeatherHourlyStripCore.focusedIndex(
                                forLocationX: localX,
                                itemWidth: itemWidth,
                                count: points.count
                            )
                            selectPoint(at: index, isDragSelection: true)
                        }
                        .onEnded { _ in
                            withAnimation(.easeOut(duration: 0.18)) {
                                isDragging = false
                            }
                        }
                )

                HStack(spacing: 0) {
                    ForEach(tickIndices(), id: \.self) { index in
                        Text(tickLabel(for: index))
                            .font(.du(9, weight: .medium))
                            .foregroundColor(Color.black.opacity(0.52))
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
            hapticPlayer.prepare()
        }
    }

    private func tickIndices() -> [Int] {
        stride(from: 0, to: min(points.count, 24), by: 3).map { $0 }
    }

    private func tickLabel(for index: Int) -> String {
        guard points.indices.contains(index) else { return "" }
        return index == 0 ? "NOW" : "\(points[index].hour24)"
    }

    private func barColor(for point: WeatherHourlyStripPoint, range: WeatherHourlyTemperatureRange, isFocused: Bool) -> Color {
        let gray = WeatherHourlyStripCore.grayscaleValue(
            temperature: point.temperature,
            minTemperature: range.low,
            maxTemperature: range.high
        )
        // Halve darkness so overall bars look lighter while preserving relative differences.
        let lighterGray = 1 - (1 - gray) * 0.5
        return Color(white: isFocused && isDragging ? min(lighterGray + 0.03, 0.96) : lighterGray)
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
