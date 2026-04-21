import SwiftUI
import UIKit

struct WeatherSunDetailOverlay: View {
    @ObservedObject var manager: WeatherSceneManager
    let size: CGSize
    let safeAreaInsets: EdgeInsets
    let interfaceOpacity: Double
    let allowsInteraction: Bool
    let onClose: () -> Void
    
    var body: some View {
        let sceneViewportHeight = min(size.height * 0.56, 470)

        ZStack {
            WeatherSunDetailBackdrop()
                .opacity(interfaceOpacity)
            
            WeatherSunDismissEdges(onDismiss: onClose)
                .opacity(interfaceOpacity)
                .allowsHitTesting(allowsInteraction)
            
            VStack(spacing: 0) {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Color.black.opacity(0.9))
                            .frame(width: 38, height: 38)
                            .background(Color.white.opacity(0.9))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: 8)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.top, 56)
                .allowsHitTesting(allowsInteraction)

                WeatherSunInteractionSurface(
                    manager: manager,
                    sceneViewportHeight: sceneViewportHeight,
                    allowsInteraction: allowsInteraction,
                    onClose: onClose
                )
                .padding(.top, 2)
                .padding(.horizontal, 6)
                .allowsHitTesting(allowsInteraction)
                
                WeatherDetailCarouselView(
                    selectedDimension: manager.currentDetailDimension,
                    width: size.width * 0.6,
                    allowsInteraction: allowsInteraction,
                    onOrbitDragChanged: { progress in
                        manager.beginDetailOrbitInteraction()
                        manager.updateDetailOrbitInteraction(progress: progress)
                    },
                    onOrbitDragEnded: { sample in
                        manager.beginDetailOrbitInteraction()
                        manager.settleDetailOrbitInteraction(sample: sample)
                    }
                )
                .frame(width: size.width * 0.6)
                .padding(.bottom, (max(safeAreaInsets.bottom, 14) + 2) * 2)
                .offset(y: (1 - interfaceOpacity) * 180)
            }
            .opacity(interfaceOpacity)
        }
        .ignoresSafeArea()
        .onAppear {
            manager.prepareDetailSecondScreen()
        }
    }
}

private struct WeatherSunDetailBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let shortestSide = min(size.width, size.height)
            let longestSide = max(size.width, size.height)
            let cornerRadius = shortestSide * 0.145
            
            ZStack {
                RadialGradient(
                    stops: [
                        .init(color: .clear, location: 0.28),
                        .init(color: Color.black.opacity(0.03), location: 0.44),
                        .init(color: Color.black.opacity(0.10), location: 0.60),
                        .init(color: Color.black.opacity(0.22), location: 0.78),
                        .init(color: Color.black.opacity(0.38), location: 0.90),
                        .init(color: Color.black.opacity(0.50), location: 1.0)
                    ],
                    center: .center,
                    startRadius: shortestSide * 0.12,
                    endRadius: longestSide * 0.82
                )
                .blendMode(.multiply)
                
                VStack(spacing: 0) {
                    LinearGradient(
                        stops: [
                            .init(color: Color.black.opacity(0.34), location: 0.0),
                            .init(color: Color.black.opacity(0.20), location: 0.32),
                            .init(color: Color.black.opacity(0.08), location: 0.68),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: size.height * 0.18)
                    .blur(radius: 10)
                    
                    Spacer(minLength: 0)
                    
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: Color.black.opacity(0.10), location: 0.30),
                            .init(color: Color.black.opacity(0.24), location: 0.66),
                            .init(color: Color.black.opacity(0.40), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: size.height * 0.22)
                    .blur(radius: 12)
                }
                .blendMode(.multiply)
                
                HStack(spacing: 0) {
                    LinearGradient(
                        stops: [
                            .init(color: Color.black.opacity(0.34), location: 0.0),
                            .init(color: Color.black.opacity(0.20), location: 0.34),
                            .init(color: Color.black.opacity(0.08), location: 0.70),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: size.width * 0.14)
                    .blur(radius: 12)
                    
                    Spacer(minLength: 0)
                    
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: Color.black.opacity(0.08), location: 0.30),
                            .init(color: Color.black.opacity(0.20), location: 0.66),
                            .init(color: Color.black.opacity(0.34), location: 1.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: size.width * 0.14)
                    .blur(radius: 12)
                }
                .blendMode(.multiply)
                
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.62), lineWidth: 12)
                    .blur(radius: 16)
                    .padding(-8)
                    .mask(
                        LinearGradient(
                            colors: [
                                Color.white,
                                Color.white.opacity(0.34),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .opacity(0.78)
                
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.28), lineWidth: 18)
                    .blur(radius: 14)
                    .padding(-6)
                    .mask(
                        LinearGradient(
                            colors: [
                                .clear,
                                Color.white.opacity(0.45),
                                Color.white
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .opacity(0.95)
                
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.32), lineWidth: 28)
                    .blur(radius: 34)
                    .padding(-20)
                    .opacity(0.84)
            }
            .compositingGroup()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// Detail-page overlay burst that radiates from the sun edge instead of the
// center, so the rays feel like a short glow flare emitted by the sun.
struct WeatherSunRayBurstBackground: View {
    let trigger: Int
    let sunCenter: CGPoint

    @State private var rays: [WeatherSunRaySpec] = []
    @State private var burstStartTime: TimeInterval = -10

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { context in
            Canvas { canvas, size in
                let elapsed = context.date.timeIntervalSinceReferenceDate - burstStartTime
                guard elapsed >= 0, elapsed <= 1.24, !rays.isEmpty else { return }

                drawRays(in: canvas, size: size, elapsed: elapsed)
            }
        }
        .onAppear {
            guard trigger > 0 else { return }
            activateBurst(for: trigger)
        }
        .onChange(of: trigger) { newValue in
            guard newValue > 0 else { return }
            activateBurst(for: newValue)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func activateBurst(for trigger: Int) {
        rays = WeatherSunRaySpec.makeSet(seed: trigger)
        burstStartTime = Date().timeIntervalSinceReferenceDate
    }

    private func drawRays(
        in canvas: GraphicsContext,
        size: CGSize,
        elapsed: TimeInterval
    ) {
        _ = size
        // Short lead-in, then a longer outward travel before the burst fades.
        let leadDelay: TimeInterval = 0.06
        let flyDuration: TimeInterval = 0.48
        let fadeDuration: TimeInterval = 0.24

        canvas.withCGContext { ctx in
            ctx.saveGState()
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.setBlendMode(.normal)

            for ray in rays {
                let localElapsed = elapsed - leadDelay - ray.delay
                guard localElapsed > 0 else { continue }

                let rayFlyDuration = flyDuration * ray.speedScale
                let rayFadeDuration = fadeDuration * (0.92 + ray.speedScale * 0.18)
                let flyProgress = min(max(localElapsed / rayFlyDuration, 0), 1)
                let fadeProgress = min(max((localElapsed - rayFlyDuration) / rayFadeDuration, 0), 1)
                let revealProgress = min(max(localElapsed / 0.04, 0), 1)
                let opacityProgress = revealProgress * (1 - fadeProgress)
                guard opacityProgress > 0.001 else { continue }

                let travel = easeOutCubic(CGFloat(flyProgress))
                // Keep the segment short and translate the whole ray outward
                // so the flare reads as motion, not as a line growing longer.
                let radialTravel = ray.travelDistance * travel
                let currentLength = ray.length * (1 - easeInOutCubic(CGFloat(flyProgress)) * 0.06)
                let startRadius = ray.originRadius + radialTravel
                let endRadius = startRadius + currentLength
                let start = point(
                    from: sunCenter,
                    angle: ray.angle,
                    distance: startRadius
                )
                let end = point(
                    from: sunCenter,
                    angle: ray.angle,
                    distance: endRadius
                )

                let alpha = ray.opacity * Double(opacityProgress)
                let color = UIColor(white: ray.white, alpha: alpha)

                ctx.saveGState()
                ctx.setShadow(offset: .zero, blur: ray.blurRadius, color: color.cgColor)
                ctx.setStrokeColor(color.cgColor)
                ctx.setLineWidth(ray.width)
                ctx.move(to: start)
                ctx.addLine(to: end)
                ctx.strokePath()
                ctx.restoreGState()
            }

            ctx.restoreGState()
        }
    }

    private func point(from center: CGPoint, angle: CGFloat, distance: CGFloat) -> CGPoint {
        CGPoint(
            x: center.x + cos(angle) * distance,
            y: center.y + sin(angle) * distance
        )
    }

    private func easeOutCubic(_ value: CGFloat) -> CGFloat {
        let reversed = 1 - value
        return 1 - reversed * reversed * reversed
    }

    private func easeInOutCubic(_ value: CGFloat) -> CGFloat {
        if value < 0.5 {
            return 4 * value * value * value
        }
        let reversed = -2 * value + 2
        return 1 - (reversed * reversed * reversed) / 2
    }
}

// Fixed-direction burst rays with controlled randomness so each tap feels a
// little different without losing the sun-flare silhouette.
private struct WeatherSunRaySpec {
    let angle: CGFloat
    let originRadius: CGFloat
    let travelDistance: CGFloat
    let length: CGFloat
    let width: CGFloat
    let opacity: Double
    let white: CGFloat
    let blurRadius: CGFloat
    let delay: CGFloat
    let speedScale: CGFloat

    static func makeSet(seed: Int, count: Int = 12) -> [WeatherSunRaySpec] {
        var generator = SeededRandomGenerator(
            seed: UInt64(max(seed, 1)) &* 0x9E3779B97F4A7C15
        )
        let rotationOffset = CGFloat.random(in: -0.55...0.55, using: &generator)
        let presetAngles: [CGFloat] = [
            -.pi / 2,
            -1.12,
            -0.52,
            -0.06,
            0.60,
            1.18,
            .pi / 2,
            2.10,
            2.68,
            .pi,
            -2.72,
            -1.92
        ]
        let maximumVisibleCount = min(count, presetAngles.count)
        let minimumVisibleCount = min(8, maximumVisibleCount)
        let visibleCount = Int.random(in: minimumVisibleCount...maximumVisibleCount, using: &generator)
        let activeAngles = Array(presetAngles.shuffled(using: &generator).prefix(visibleCount))

        return activeAngles.enumerated().map { index, baseAngle in
            let randomSpread = CGFloat.random(in: -0.12...0.12, using: &generator)
            let isAxisRay = index.isMultiple(of: 3)

            return WeatherSunRaySpec(
                angle: baseAngle + rotationOffset + randomSpread,
                // Let some rays start near the rim and some slightly inside
                // the sun so the burst feels less mechanically uniform.
                originRadius: CGFloat.random(in: isAxisRay ? 84...132 : 76...124, using: &generator),
                travelDistance: CGFloat.random(in: isAxisRay ? 28...36 : 22...30, using: &generator),
                length: CGFloat.random(in: isAxisRay ? 8...11 : 6...9, using: &generator),
                width: CGFloat.random(in: isAxisRay ? 1.95...2.75 : 1.45...2.2, using: &generator),
                opacity: Double.random(in: isAxisRay ? 0.62...0.80 : 0.50...0.68, using: &generator),
                // Keep the existing tone as the darkest baseline and randomize
                // toward lighter variants so the burst has subtle depth.
                white: CGFloat.random(in: 0.03...0.20, using: &generator),
                blurRadius: CGFloat.random(in: 0.3...0.9, using: &generator),
                delay: CGFloat.random(in: 0...0.04, using: &generator),
                speedScale: CGFloat.random(in: 0.82...1.18, using: &generator)
            )
        }
    }
}

private struct SeededRandomGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x123456789ABCDEF : seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

private struct WeatherSunDismissEdges: View {
    let onDismiss: () -> Void
    
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: min(150, proxy.size.height * 0.18))
                        .contentShape(Rectangle())
                        .onTapGesture(perform: onDismiss)
                    Spacer(minLength: 0)
                }
                
                HStack(spacing: 0) {
                    Color.clear
                        .frame(width: 30)
                        .contentShape(Rectangle())
                        .onTapGesture(perform: onDismiss)
                    
                    Spacer(minLength: 0)
                    
                    Color.clear
                        .frame(width: 30)
                        .contentShape(Rectangle())
                        .onTapGesture(perform: onDismiss)
                }
            }
        }
    }
}

private struct WeatherSunInteractionSurface: View {
    let manager: WeatherSceneManager
    let sceneViewportHeight: CGFloat
    let allowsInteraction: Bool
    let onClose: () -> Void

    @State private var activeZone: WeatherSecondScreenInteractionZone = .none
    @State private var dragStartTime: Date?

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                Color.clear
                    .frame(height: sceneViewportHeight)

                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .contentShape(Rectangle())
            .gesture(surfaceGesture(in: proxy.size))
        }
    }

    private func surfaceGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .local)
            .onChanged { value in
                guard allowsInteraction else { return }

                if activeZone == .none {
                    activeZone = hitZones(in: size).zone(at: value.startLocation)
                    dragStartTime = Date()

                    switch activeZone {
                    case .selfSpin:
                        manager.beginDetailSelfSpinInteraction()
                    case .orbit:
                        manager.beginDetailOrbitInteraction()
                    default:
                        break
                    }
                }

                switch activeZone {
                case .selfSpin:
                    manager.updateDetailSelfSpinInteraction(translation: value.translation)
                case .orbit:
                    manager.updateDetailOrbitInteraction(
                        progress: -value.translation.width / max(size.width, 1)
                    )
                default:
                    break
                }
            }
            .onEnded { value in
                defer {
                    activeZone = .none
                    dragStartTime = nil
                }

                guard allowsInteraction else { return }

                switch activeZone {
                case .selfSpin:
                    manager.endDetailSelfSpinInteraction()
                case .orbit:
                    let translation = value.translation.width
                    let predicted = value.predictedEndTranslation.width
                    let duration = max(Date().timeIntervalSince(dragStartTime ?? Date()), 0.01)
                    let velocity = -(predicted - translation) / 0.12

                    manager.settleDetailOrbitInteraction(
                        sample: WeatherSecondScreenOrbitGestureSample(
                            translationRatio: -translation / max(size.width, 1),
                            predictedTranslationRatio: -predicted / max(size.width, 1),
                            velocityPointsPerSecond: velocity,
                            duration: duration
                        )
                    )
                case .close:
                    onClose()
                default:
                    break
                }
            }
    }

    private func hitZones(in size: CGSize) -> WeatherSecondScreenHitZones {
        let closeHeight = min(24, size.height * 0.08)
        let selfSpinWidth = size.width * 0.68
        let selfSpinHeight = sceneViewportHeight * 0.84
        let selfSpinX = (size.width - selfSpinWidth) / 2
        let selfSpinY = max(0, sceneViewportHeight * 0.05)

        return WeatherSecondScreenHitZones(
            closeZone: CGRect(x: 0, y: 0, width: size.width, height: closeHeight),
            dayWeekZone: .null,
            nowTimelineZone: .null,
            selfSpinZone: CGRect(
                x: selfSpinX,
                y: selfSpinY,
                width: selfSpinWidth,
                height: selfSpinHeight
            ),
            orbitZone: CGRect(x: 0, y: 0, width: size.width, height: size.height)
        )
    }
}

private struct WeatherSunInsightPanel: View {
    private let uvCurve: [CGFloat] = [3.2, 2.4, 1.1, 0.3, 0.2, 0.2, 0.2, 1.7, 2.8, 6.1, 7.0, 8.8, 9.6, 7.8]
    
    var body: some View {
        VStack(spacing: 8) {
            metricRow(title: "UV", value: "4", highlighted: true)
            metricRow(title: "Sunrise", value: "6:06 AM", highlighted: false)
            metricRow(title: "Sunset", value: "6:36 PM", highlighted: false)
            
            HStack {
                Text("Now")
                Spacer()
                Text("18")
                Spacer()
                Text("0")
                Spacer()
                Text("6")
                Spacer()
                Text("12")
            }
            .font(.du(9, weight: .medium))
            .foregroundColor(Color.black.opacity(0.72))
            .padding(.horizontal, 14)
            .padding(.top, 2)
            
            WeatherSunCurveView(values: uvCurve)
                .frame(height: 78)
            
            WeatherSunTimelineSlider()
            
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
        }
        .padding(.horizontal, 12)
        .frame(height: highlighted ? 28 : 22)
        .background(
            Capsule()
                .fill(highlighted ? Color.black.opacity(0.92) : Color.clear)
        )
    }
}

private struct WeatherSunTimelineSlider: View {
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

private struct WeatherSunCurveView: View {
    let values: [CGFloat]
    
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let maxValue = max(values.max() ?? 1, 1)
            
            ZStack(alignment: .topLeading) {
                Path { path in
                    for index in values.indices {
                        let x = CGFloat(index) / CGFloat(max(values.count - 1, 1)) * (width - 24) + 12
                        let y = (1 - values[index] / maxValue) * (height - 28) + 4
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color.black.opacity(0.88), style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round))
                
                VStack(alignment: .trailing, spacing: 18) {
                    Text("10")
                    Text("5")
                    Text("0")
                }
                .font(.du(10, weight: .medium))
                .foregroundColor(Color.black.opacity(0.84))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 3)
                .padding(.trailing, -14)
            }
        }
    }
}
