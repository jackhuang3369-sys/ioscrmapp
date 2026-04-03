import SwiftUI

struct WeatherWindBackgroundView: View {
    @State private var strands = WindStrand.makeStructuredSet(count: 9)
    @State private var particles = WindParticle.makeRandomSet(count: 16)

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
                Canvas { canvas, size in
                    let time = context.date.timeIntervalSinceReferenceDate

                    for strand in strands {
                        let path = strand.path(in: size, time: time)
                        canvas.stroke(
                            path,
                            with: .color(.black.opacity(strand.opacity)),
                            style: StrokeStyle(
                                lineWidth: strand.lineWidth,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                    }

                    for particle in particles {
                        let state = particle.state(in: size, time: time)
                        guard state.center.x >= -16, state.center.x <= size.width + 16 else { continue }
                        guard state.center.y >= -16, state.center.y <= size.height + 16 else { continue }

                        var square = Path()
                        square.addRoundedRect(
                            in: CGRect(
                                x: -state.size / 2,
                                y: -state.size / 2,
                                width: state.size,
                                height: state.size
                            ),
                            cornerSize: CGSize(width: state.cornerRadius, height: state.cornerRadius)
                        )

                        canvas.withCGContext { context in
                            context.saveGState()
                            context.translateBy(x: state.center.x, y: state.center.y)
                            context.rotate(by: state.rotation)
                            context.setAlpha(particle.opacity)
                            context.setFillColor(UIColor.black.cgColor)
                            context.addPath(square.cgPath)
                            context.fillPath()
                            context.restoreGState()
                        }
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct WindStrand: Identifiable {
    let id = UUID()
    let baseY: CGFloat
    let amplitude: CGFloat
    let length: CGFloat
    let driftSpeed: Double
    let waveSpeed: Double
    let phase: Double
    let secondaryPhase: Double
    let lineWidth: CGFloat
    let opacity: Double
    let startOffset: CGFloat
    let primarySpatialFrequency: CGFloat
    let secondarySpatialFrequency: CGFloat

    func path(in size: CGSize, time: TimeInterval) -> Path {
        let offscreenPadding: CGFloat = 96
        let travelWidth = size.width + length + offscreenPadding * 2
        let cycle = CGFloat((time * driftSpeed).truncatingRemainder(dividingBy: Double(travelWidth)))
        let startX = size.width + offscreenPadding + startOffset * travelWidth - cycle
        let sampleCount = 48

        var path = Path()
        var didMove = false

        for index in 0...sampleCount {
            let progress = CGFloat(index) / CGFloat(sampleCount)
            let x = startX + progress * length
            let leadingFade = sin(progress * .pi)
            let primaryWave = sin(progress * .pi * 2 * primarySpatialFrequency + phase + time * waveSpeed) * amplitude
            let secondaryWave = sin(progress * .pi * 2 * secondarySpatialFrequency + secondaryPhase + time * waveSpeed * 0.82) * amplitude * 0.22
            let yOffset = (primaryWave + secondaryWave) * (0.55 + leadingFade * 0.45)
            let y = size.height * baseY + yOffset
            let point = CGPoint(x: x, y: y)

            if !didMove {
                path.move(to: point)
                didMove = true
            } else {
                path.addLine(to: point)
            }
        }

        return path
    }

    static func makeStructuredSet(count: Int) -> [WindStrand] {
        let amplitudes: [CGFloat] = [5.0, 5.8, 5.2, 6.2, 5.1, 5.6, 4.8, 6.0, 5.3]
        let lengths: [CGFloat] = [52, 58, 50, 64, 54, 60, 48, 62, 56]
        let driftSpeeds: [Double] = [74, 82, 88, 78, 92, 80, 86, 76, 90]
        let waveSpeeds: [Double] = [1.32, 1.56, 1.44, 1.68, 1.38, 1.60, 1.48, 1.72, 1.40]
        let phases: [Double] = [0.1, 0.9, 1.7, 2.4, 3.0, 3.8, 4.5, 5.2, 5.8]
        let secondaryPhases: [Double] = [1.4, 2.1, 2.8, 3.6, 4.2, 4.9, 5.6, 0.7, 1.9]
        let lineWidths: [CGFloat] = [1.35, 1.1, 1.25, 1.4, 1.05, 1.2, 1.0, 1.3, 1.15]
        let opacities: [Double] = [0.14, 0.11, 0.13, 0.15, 0.10, 0.12, 0.11, 0.14, 0.12]
        let primaryFrequencies: [CGFloat] = [0.95, 1.02, 0.92, 1.08, 0.98, 1.04, 0.90, 1.10, 1.00]
        let secondaryFrequencies: [CGFloat] = [1.85, 1.72, 1.92, 1.68, 1.88, 1.76, 1.96, 1.70, 1.82]

        return (0..<count).map { index in
            let slot = CGFloat(index + 1) / CGFloat(count + 1)
            let verticalJitter = CGFloat.random(in: -0.018...0.018)
            let horizontalJitter = CGFloat.random(in: -0.035...0.035)
            return WindStrand(
                baseY: min(max(slot + verticalJitter, 0.14), 0.9),
                amplitude: amplitudes[index % amplitudes.count],
                length: lengths[index % lengths.count],
                driftSpeed: driftSpeeds[index % driftSpeeds.count],
                waveSpeed: waveSpeeds[index % waveSpeeds.count],
                phase: phases[index % phases.count],
                secondaryPhase: secondaryPhases[index % secondaryPhases.count],
                lineWidth: lineWidths[index % lineWidths.count],
                opacity: opacities[index % opacities.count],
                startOffset: min(max(CGFloat(index) / CGFloat(count) + horizontalJitter, 0), 0.98),
                primarySpatialFrequency: primaryFrequencies[index % primaryFrequencies.count],
                secondarySpatialFrequency: secondaryFrequencies[index % secondaryFrequencies.count]
            )
        }
    }
}

private struct WindParticle {
    let baseY: CGFloat
    let driftSpeed: Double
    let verticalAmplitude: CGFloat
    let verticalSpeed: Double
    let size: CGFloat
    let opacity: Double
    let rotationSpeed: Double
    let phase: Double
    let startOffset: CGFloat
    let cornerRadius: CGFloat

    func state(in viewportSize: CGSize, time: TimeInterval) -> WindParticleState {
        let offscreenPadding: CGFloat = 40
        let travelWidth = viewportSize.width + offscreenPadding * 2 + self.size * 2
        let cycle = CGFloat((time * driftSpeed).truncatingRemainder(dividingBy: Double(travelWidth)))
        let x = viewportSize.width + offscreenPadding + startOffset * travelWidth - cycle
        let verticalWave = sin(phase + time * verticalSpeed) * verticalAmplitude
        let center = CGPoint(x: x, y: viewportSize.height * baseY + verticalWave)
        let rotation = phase + time * rotationSpeed
        return WindParticleState(center: center, size: self.size, cornerRadius: cornerRadius, rotation: rotation)
    }

    static func makeRandomSet(count: Int) -> [WindParticle] {
        (0..<count).map { _ in
            WindParticle(
                baseY: .random(in: 0.12...0.9),
                driftSpeed: .random(in: 52...92),
                verticalAmplitude: .random(in: 2...7),
                verticalSpeed: .random(in: 0.35...0.9),
                size: .random(in: 3.5...7.5),
                opacity: .random(in: 0.08...0.16),
                rotationSpeed: .random(in: 0.7...1.8),
                phase: .random(in: 0...(Double.pi * 2)),
                startOffset: .random(in: 0...1),
                cornerRadius: .random(in: 0.5...1.6)
            )
        }
    }
}

private struct WindParticleState {
    let center: CGPoint
    let size: CGFloat
    let cornerRadius: CGFloat
    let rotation: Double
}