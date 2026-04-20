import SwiftUI

struct WeatherDetailCarouselView: View {
    @Binding var selectedDimension: WeatherDetailDimension

    let width: CGFloat
    let allowsInteraction: Bool
    let onProgressChange: (WeatherDetailDimension, CGFloat, Bool) -> Void

    @State private var dragTranslation: CGFloat = 0
    @State private var dragDirection: DragDirection?

    private let switchThresholdRatio: CGFloat = 0.18
    private let flingThresholdRatio: CGFloat = 0.34

    private enum DragDirection: Equatable {
        case horizontal
        case vertical
    }

    var body: some View {
        let referenceWidth = max(width, 1)

        ZStack {
            WeatherDetailInsightPanel(snapshot: .mock(for: selectedDimension))
                .frame(width: width)
                .opacity(panelOpacity)
                .offset(x: dragTranslation * 0.10)
                .id(selectedDimension)
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .offset(x: 18)),
                        removal: .opacity.combined(with: .offset(x: -18))
                    )
                )
        }
        .frame(width: width, height: 232)
        .contentShape(Rectangle())
        .gesture(pagerGesture(referenceWidth: referenceWidth))
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: selectedDimension)
        .onAppear {
            onProgressChange(selectedDimension, 0, false)
        }
    }

    private func pagerGesture(referenceWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .onChanged { value in
                guard allowsInteraction else {
                    resetDrag(animated: true)
                    return
                }

                if dragDirection == nil {
                    dragDirection = resolvedDragDirection(for: value)
                }

                guard dragDirection == .horizontal else { return }

                let clampedTranslation = clamped(
                    value.translation.width,
                    lower: -referenceWidth,
                    upper: referenceWidth
                )
                dragTranslation = clampedTranslation
                onProgressChange(
                    selectedDimension,
                    -clampedTranslation / referenceWidth,
                    false
                )
            }
            .onEnded { value in
                let resolvedDirection = dragDirection ?? resolvedDragDirection(for: value)
                defer { dragDirection = nil }

                guard allowsInteraction, resolvedDirection == .horizontal else {
                    resetDrag(animated: true)
                    return
                }

                let threshold = referenceWidth * switchThresholdRatio
                let flingThreshold = referenceWidth * flingThresholdRatio
                let translation = clamped(
                    value.translation.width,
                    lower: -referenceWidth,
                    upper: referenceWidth
                )
                let predicted = clamped(
                    value.predictedEndTranslation.width,
                    lower: -referenceWidth,
                    upper: referenceWidth
                )
                let nextOffset: Int

                if translation <= -threshold || predicted <= -flingThreshold {
                    nextOffset = 1
                } else if translation >= threshold || predicted >= flingThreshold {
                    nextOffset = -1
                } else {
                    nextOffset = 0
                }

                let nextDimension = selectedDimension.advanced(by: nextOffset)
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    selectedDimension = nextDimension
                    dragTranslation = 0
                }
                onProgressChange(nextDimension, 0, true)
            }
    }

    private func resetDrag(animated: Bool) {
        let changes = {
            dragTranslation = 0
        }

        if animated {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                changes()
            }
        } else {
            changes()
        }
        onProgressChange(selectedDimension, 0, animated)
    }

    private func resolvedDragDirection(for value: DragGesture.Value) -> DragDirection? {
        let horizontalDistance = abs(value.translation.width)
        let verticalDistance = abs(value.translation.height)
        guard max(horizontalDistance, verticalDistance) > 4 else { return nil }
        return horizontalDistance >= verticalDistance * 1.08 ? .horizontal : .vertical
    }

    private func clamped(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }

    private var panelOpacity: Double {
        Double(max(0.62, 1 - abs(dragTranslation / max(width, 1)) * 0.34))
    }
}

private struct WeatherDetailInsightPanel: View {
    let snapshot: WeatherDetailSnapshot

    var body: some View {
        VStack(spacing: 8) {
            metricRow(
                title: highlightedTitle,
                value: highlightedValue,
                highlighted: true
            )

            ForEach(snapshot.metrics.prefix(2)) { metric in
                metricRow(title: metric.title, value: metric.value, highlighted: false)
            }

            HStack {
                ForEach(Array(snapshot.chartLabels.enumerated()), id: \.offset) { index, label in
                    Text(label)
                    if index < snapshot.chartLabels.count - 1 {
                        Spacer()
                    }
                }
            }
            .font(.du(9, weight: .medium))
            .foregroundColor(Color.black.opacity(0.72))
            .padding(.horizontal, 14)
            .padding(.top, 2)

            WeatherDetailCurveView(
                values: snapshot.chartValues,
                style: snapshot.chartStyle
            )
            .frame(height: 78)

            WeatherDetailTimelineSlider()

            HStack {
                Spacer(minLength: 0)

                HStack(spacing: 10) {
                    Text("Day")
                        .font(.du(11, weight: .medium))
                        .foregroundColor(Color.black.opacity(0.90))

                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.black.opacity(0.12))

                        Circle()
                            .fill(Color.black.opacity(0.88))
                            .padding(4)
                    }
                    .frame(width: 52, height: 26)

                    Text("Week")
                        .font(.du(11, weight: .medium))
                        .foregroundColor(Color.black.opacity(0.18))
                }

                Spacer(minLength: 0)
            }
            .padding(.top, 1)
        }
        .padding(.horizontal, 2)
    }

    private var highlightedTitle: String {
        switch snapshot.dimension {
        case .sun:
            return "UV"
        case .cloud:
            return "Cloud"
        case .air:
            return "Wind"
        case .moon:
            return "Light"
        case .temperature:
            return "Temp"
        case .precipitation:
            return "Rain"
        }
    }

    private var highlightedValue: String {
        switch snapshot.dimension {
        case .sun:
            return snapshot.primaryValue
        default:
            return "\(snapshot.primaryValue)\(snapshot.primaryUnit)"
        }
    }

    private func metricRow(title: String, value: String, highlighted: Bool) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.du(10, weight: .medium))
                .kerning(0.9)
                .foregroundColor(highlighted ? Color.white.opacity(0.96) : Color.black.opacity(0.88))
                .frame(width: 92, alignment: .leading)

            Rectangle()
                .fill(highlighted ? Color.white.opacity(0.22) : Color.black.opacity(0.12))
                .frame(height: 1)

            Text(value)
                .font(.du(highlighted ? 15 : 11, weight: .medium))
                .foregroundColor(highlighted ? Color.white.opacity(0.96) : Color.black.opacity(0.88))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 12)
        .frame(height: highlighted ? 28 : 22)
        .background(
            Capsule()
                .fill(highlighted ? Color.black.opacity(0.92) : Color.clear)
        )
    }
}

private struct WeatherDetailTimelineSlider: View {
    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.black.opacity(0.10))
                .frame(height: 7)

            HStack(spacing: 0) {
                Circle()
                    .fill(Color.black.opacity(0.92))
                    .frame(width: 16, height: 16)

                Spacer(minLength: 0)
            }

            HStack(spacing: 11) {
                Spacer().frame(width: 16)
                ForEach(0..<17, id: \.self) { _ in
                    Circle()
                        .fill(Color.black.opacity(0.22))
                        .frame(width: 1.5, height: 1.5)
                }
                Spacer().frame(width: 8)
            }
        }
        .padding(.horizontal, 2)
    }
}

private struct WeatherDetailCurveView: View {
    let values: [CGFloat]
    let style: WeatherDetailChartStyle

    var body: some View {
        GeometryReader { proxy in
            let points = chartPoints(in: proxy.size)

            ZStack(alignment: .topLeading) {
                if style == .area {
                    areaPath(points: points, size: proxy.size)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.16),
                                    Color.black.opacity(0.02)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }

                linePath(points: points)
                    .stroke(
                        Color.black.opacity(0.88),
                        style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round)
                    )

                VStack(alignment: .trailing, spacing: 18) {
                    Text(axisLabel(at: 1))
                    Text(axisLabel(at: 0.5))
                    Text(axisLabel(at: 0))
                }
                .font(.du(10, weight: .medium))
                .foregroundColor(Color.black.opacity(0.84))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 3)
                .padding(.trailing, -14)
            }
        }
    }

    private func chartPoints(in size: CGSize) -> [CGPoint] {
        guard !values.isEmpty else { return [] }

        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let range = max(maxValue - minValue, 0.1)
        let drawableWidth = max(size.width - 24, 1)
        let drawableHeight = max(size.height - 28, 1)

        return values.enumerated().map { index, value in
            let x = CGFloat(index) / CGFloat(max(values.count - 1, 1)) * drawableWidth + 12
            let normalized = (value - minValue) / range
            let y = (1 - normalized) * drawableHeight + 4
            return CGPoint(x: x, y: y)
        }
    }

    private func linePath(points: [CGPoint]) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
        }
    }

    private func areaPath(points: [CGPoint], size: CGSize) -> Path {
        Path { path in
            guard let first = points.first, let last = points.last else { return }
            path.move(to: CGPoint(x: first.x, y: size.height))
            path.addLine(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            path.addLine(to: CGPoint(x: last.x, y: size.height))
            path.closeSubpath()
        }
    }

    private func axisLabel(at ratio: CGFloat) -> String {
        let maxValue = values.max() ?? 0
        let value = maxValue * ratio
        if maxValue < 10 {
            return String(format: "%.1f", value)
        }
        return "\(Int(value.rounded()))"
    }
}
