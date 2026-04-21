import SwiftUI

// MARK: - WeatherWindBackgroundView

struct WeatherWindBackgroundView: View {
    let isPaused: Bool
    private let strands   = WindStrand.makePresetSet()
    private let particles = WindParticle.makePresetSet()

    init(isPaused: Bool = false) {
        self.isPaused = isPaused
    }

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: isPaused)) { context in
                Canvas { canvas, size in
                    let time = context.date.timeIntervalSinceReferenceDate
                    for strand in strands {
                        strand.draw(in: canvas, size: size, time: time)
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

                        canvas.withCGContext { ctx in
                            ctx.saveGState()
                            ctx.translateBy(x: state.center.x, y: state.center.y)
                            ctx.rotate(by: state.rotation)
                            ctx.setAlpha(particle.opacity)
                            ctx.setFillColor(UIColor(red: 0.03, green: 0.03, blue: 0.04, alpha: 1).cgColor)
                            ctx.addPath(square.cgPath)
                            ctx.fillPath()
                            ctx.restoreGState()
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

// MARK: - WindStrand

/// 一条风线，从屏幕右侧平滑穿越到左侧：
/// - 位置由连续时间驱动，无随机跳变，不再闪烁
/// - 主次波叠加 + 正弦包络，两端波幅收缩至 0，视觉上"越来越短"
/// - 透明度跟随包络渐变，头尾淡出，中段最亮
/// - 波浪相位随 crawlSpeed 向左滚动，呈现"往左爬行"感
private struct WindStrand {
    /// 纵向基准位置（0~1，相对屏幕高度）
    let baseY: CGFloat
    /// 波浪最大幅度（points）
    let amplitude: CGFloat
    /// 线段最大长度（points）
    let maxLength: CGFloat
    /// 向左平移速度（points/s）
    let speed: Double
    /// 波形向左爬行速度（rad/s）
    let crawlSpeed: Double
    /// 周期内时间偏移比例（0~1），使各条线在时间轴上自然错开
    let phaseOffset: Double
    /// 线宽（points）
    let lineWidth: CGFloat
    /// 最大不透明度
    let opacity: Double
    /// 波长（points）
    let wavelength: CGFloat

    func draw(in canvas: GraphicsContext, size: CGSize, time: TimeInterval) {
        // 线头（左端）从 size.width + pad 出发向左，到 -(maxLength + pad) 结束，构成完整行程
        let pad: CGFloat = 60
        let travelWidth = size.width + maxLength + pad * 2

        // phaseOffset 在时间轴上偏移各线的起始位置，保证相位连续、不跳变
        let elapsed = time * speed + phaseOffset * Double(travelWidth)
        let traveled = CGFloat(elapsed.truncatingRemainder(dividingBy: Double(travelWidth)))

        let headX = size.width + pad - traveled   // 线头（左端/前端）x
        let tailX = headX + maxLength             // 线尾（右端）x

        // 仅当线有部分在屏幕内（含一小段缓冲）才绘制
        guard tailX > -pad && headX < size.width + pad else { return }

        // 波形爬行相位：随时间增大，相位向左推进（sin 函数自变量增大 → 波形向左传播）
        let crawlPhase = CGFloat(time * crawlSpeed)

        let sampleCount = max(24, Int(maxLength / 3.0))
        var pts    = [CGPoint](); pts.reserveCapacity(sampleCount + 1)
        var alphas = [CGFloat](); alphas.reserveCapacity(sampleCount + 1)

        let centerY = size.height * baseY

        for i in 0...sampleCount {
            let t = CGFloat(i) / CGFloat(sampleCount)
            let x = headX + t * maxLength

            // 主次双频波叠加，增加真实感；黄金比例次频避免过于规整
            let arg  = t * .pi * 2.0 * (maxLength / wavelength) - crawlPhase
            let wave = sin(arg) + sin(arg * 1.618 + 1.0) * 0.30

            // 正弦包络：t=0/1 时为 0，t=0.5 时为 1，幅度两端自然收缩
            let env = sin(t * .pi)
            let y   = centerY + wave * amplitude * env
            pts.append(CGPoint(x: x, y: y))

            // alpha 同样随包络渐变，1.5 次方使过渡曲线更柔和
            alphas.append(CGFloat(opacity) * pow(env, 1.5))
        }

        guard pts.count >= 2 else { return }

        // 逐段描边：每段取两端点 alpha 均值作为该段颜色透明度，实现渐变效果
        canvas.withCGContext { ctx in
            ctx.saveGState()
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.setLineWidth(lineWidth)
            for seg in 0..<sampleCount {
                let a = (alphas[seg] + alphas[seg + 1]) * 0.5
                guard a > 0.006 else { continue }
                ctx.setStrokeColor(UIColor(red: 0.03, green: 0.03, blue: 0.04, alpha: a).cgColor)
                ctx.move(to: pts[seg])
                ctx.addLine(to: pts[seg + 1])
                ctx.strokePath()
            }
            ctx.restoreGState()
        }
    }

    static func makePresetSet() -> [WindStrand] {
        // 5 条风线，均匀分布屏幕高度
        [
            // WindStrand(baseY: 0.19, amplitude:  8, maxLength: 100, speed:  62, crawlSpeed: 2.7, phaseOffset: 0.00, lineWidth: 1.9, opacity: 0.62, wavelength: 110),
            WindStrand(baseY: 0.39, amplitude: 10, maxLength: 100, speed:  56, crawlSpeed: 2.9, phaseOffset: 0.20, lineWidth: 2.2, opacity: 0.33, wavelength: 110),
            WindStrand(baseY: 0.55, amplitude:  7, maxLength:  90, speed:  70, crawlSpeed: 2.1, phaseOffset: 0.42, lineWidth: 1.7, opacity: 0.36, wavelength:  90),
            WindStrand(baseY: 0.70, amplitude:  9, maxLength: 110, speed:  61, crawlSpeed: 2.5, phaseOffset: 0.65, lineWidth: 1.8, opacity: 0.30, wavelength: 100),
            // WindStrand(baseY: 0.85, amplitude:  6, maxLength:  80, speed:  76, crawlSpeed: 2.0, phaseOffset: 0.85, lineWidth: 1.5, opacity: 0.52, wavelength:  80),
        ]
    }
}

// MARK: - WindParticle

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

    static func makePresetSet() -> [WindParticle] {
        [
            WindParticle(baseY: 0.18, driftSpeed: 74, verticalAmplitude: 4, verticalSpeed: 0.54, size: 4.0, opacity: 0.18, rotationSpeed: 0.95, phase: 0.3, startOffset: 0.04, cornerRadius: 1.0),
            WindParticle(baseY: 0.28, driftSpeed: 78, verticalAmplitude: 5, verticalSpeed: 0.60, size: 4.8, opacity: 0.19, rotationSpeed: 1.10, phase: 0.9, startOffset: 0.16, cornerRadius: 1.1),
            WindParticle(baseY: 0.39, driftSpeed: 76, verticalAmplitude: 3, verticalSpeed: 0.50, size: 4.2, opacity: 0.17, rotationSpeed: 0.98, phase: 1.6, startOffset: 0.30, cornerRadius: 0.9),
            WindParticle(baseY: 0.50, driftSpeed: 80, verticalAmplitude: 6, verticalSpeed: 0.64, size: 5.4, opacity: 0.20, rotationSpeed: 1.22, phase: 2.4, startOffset: 0.43, cornerRadius: 1.3),
            WindParticle(baseY: 0.61, driftSpeed: 75, verticalAmplitude: 4, verticalSpeed: 0.56, size: 4.6, opacity: 0.18, rotationSpeed: 1.02, phase: 3.1, startOffset: 0.57, cornerRadius: 1.0),
            WindParticle(baseY: 0.71, driftSpeed: 79, verticalAmplitude: 5, verticalSpeed: 0.61, size: 5.2, opacity: 0.20, rotationSpeed: 1.18, phase: 3.8, startOffset: 0.69, cornerRadius: 1.2),
            WindParticle(baseY: 0.82, driftSpeed: 77, verticalAmplitude: 3, verticalSpeed: 0.48, size: 4.0, opacity: 0.17, rotationSpeed: 0.92, phase: 4.5, startOffset: 0.83, cornerRadius: 0.9),
            WindParticle(baseY: 0.90, driftSpeed: 81, verticalAmplitude: 2.5, verticalSpeed: 0.46, size: 3.6, opacity: 0.17, rotationSpeed: 0.88, phase: 5.1, startOffset: 0.94, cornerRadius: 0.8)
        ]
    }
}

private struct WindParticleState {
    let center: CGPoint
    let size: CGFloat
    let cornerRadius: CGFloat
    let rotation: Double
}
