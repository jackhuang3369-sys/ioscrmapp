import SwiftUI

// MARK: - Bolt Travel Dreamscape
/// 旅行梦境抽象艺术 — 替代普通渐变占位图
/// 用多层几何形态、光晕和微动效打造沉浸式视觉
struct BoltTravelDreamscape: View {
    let destination: String
    let transportMode: TravelTransportMode
    @State private var phase: Double = 0

    var palette: (primary: Color, accent: Color, deep: Color) {
        switch transportMode {
        case .flight: return (BoltTheme.skyBlue, BoltTheme.gold, BoltTheme.oceanDeep)
        case .train:  return (BoltTheme.forest, BoltTheme.amber, Color(hex: 0x1B3A2D))
        case .bus:    return (BoltTheme.amber, BoltTheme.sunset, Color(hex: 0x3D2010))
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 深邃底色
                palette.deep

                // 第一层：大环形光晕
                Circle()
                    .fill(RadialGradient(
                        colors: [palette.accent.opacity(0.35), palette.accent.opacity(0.05), .clear],
                        center: .center, startRadius: 0, endRadius: geo.size.width * 0.7))
                    .frame(width: geo.size.width * 1.6, height: geo.size.width * 1.6)
                    .offset(x: -geo.size.width * 0.2 + CGFloat(sin(phase * 0.3) * 8),
                            y: -geo.size.height * 0.3 + CGFloat(cos(phase * 0.25) * 10))

                // 第二层：交叉环形
                Circle()
                    .stroke(palette.primary.opacity(0.18), lineWidth: 1.5)
                    .frame(width: geo.size.width * 0.9, height: geo.size.width * 0.9)
                    .offset(x: geo.size.width * 0.35 + CGFloat(sin(phase * 0.35) * 12),
                            y: -geo.size.height * 0.15)

                Circle()
                    .stroke(palette.accent.opacity(0.12), lineWidth: 1)
                    .frame(width: geo.size.width * 0.7, height: geo.size.width * 0.7)
                    .offset(x: -geo.size.width * 0.25 + CGFloat(cos(phase * 0.3) * 8),
                            y: geo.size.height * 0.2 + CGFloat(sin(phase * 0.28) * 6))

                // 第三层：大环形光晕（后置）
                Circle()
                    .fill(
                        RadialGradient(colors: [palette.primary.opacity(0.25), palette.primary.opacity(0.04), .clear],
                                       center: .center, startRadius: 0, endRadius: geo.size.width * 0.55))
                    .frame(width: geo.size.width * 1.1, height: geo.size.width * 1.1)
                    .offset(x: geo.size.width * 0.15 + CGFloat(sin(phase * 0.4) * 15),
                            y: geo.size.height * 0.25)

                // 第四层：几何网格线
                GeometryGrid(density: 12, opacity: 0.03, color: palette.primary)
                    .mask(
                        RadialGradient(colors: [.white, .clear], center: .topTrailing,
                                       startRadius: geo.size.width * 0.3, endRadius: geo.size.width * 0.9)
                    )

                // 第五层：点缀小光点
                Circle()
                    .fill(palette.accent.opacity(0.5))
                    .frame(width: 4, height: 4)
                    .blur(radius: 2)
                    .offset(x: geo.size.width * 0.25, y: -geo.size.height * 0.2)
                    .scaleEffect(CGFloat(1.0 + sin(phase * 1.5) * 0.4))

                Circle()
                    .fill(palette.primary.opacity(0.45))
                    .frame(width: 3, height: 3)
                    .blur(radius: 1.5)
                    .offset(x: -geo.size.width * 0.3, y: geo.size.height * 0.12)
                    .scaleEffect(CGFloat(1.0 + cos(phase * 1.3) * 0.35))

                Circle()
                    .fill(BoltTheme.gold.opacity(0.4))
                    .frame(width: 2.5, height: 2.5)
                    .blur(radius: 1)
                    .offset(x: geo.size.width * 0.05, y: -geo.size.height * 0.3)
                    .scaleEffect(CGFloat(1.0 + sin(phase * 1.1) * 0.5))

                // 目的地文字叠加
                VStack {
                    Spacer()
                    HStack {
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.1))
                                .frame(width: 8, height: 8)
                            Circle()
                                .fill(palette.accent)
                                .frame(width: 5, height: 5)
                        }
                        Text(destination)
                            .font(BoltTheme.headingFont(15))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 0.5))
                    )
                    .padding(.leading, 14)
                    .padding(.bottom, 12)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .clipped()
        .onAppear {
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}

// MARK: - Geometry Grid
private struct GeometryGrid: View {
    let density: Int
    let opacity: Double
    let color: Color

    var body: some View {
        Canvas { ctx, size in
            let stepX = size.width / CGFloat(density)
            let stepY = size.height / CGFloat(density)
            for i in 0...density {
                var pathH = Path()
                pathH.move(to: CGPoint(x: 0, y: stepY * CGFloat(i)))
                pathH.addLine(to: CGPoint(x: size.width, y: stepY * CGFloat(i)))
                ctx.stroke(pathH, with: .color(color.opacity(opacity)), lineWidth: 0.5)

                var pathV = Path()
                pathV.move(to: CGPoint(x: stepX * CGFloat(i), y: 0))
                pathV.addLine(to: CGPoint(x: stepX * CGFloat(i), y: size.height))
                ctx.stroke(pathV, with: .color(color.opacity(opacity)), lineWidth: 0.5)
            }
        }
    }
}
