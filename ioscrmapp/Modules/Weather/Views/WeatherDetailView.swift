import SwiftUI

// MARK: - WeatherDetailView（页面 B 根视图 — 4维度循环面板）

struct WeatherDetailView: View {
    let weather: CurrentWeather
    let detail: WeatherDetailData

    @Environment(\.dismiss) private var dismiss

    // Extended list enables infinite looping:
    //   index 0 → last (sentinel pre)
    //   index 1…4 → real allCases
    //   index 5 → first (sentinel post)
    private static let allDims   = WeatherDetailDimension.allCases
    private static let extended: [WeatherDetailDimension] = [allDims.last!] + allDims + [allDims.first!]

    @State private var page: Int = 1   // start on first real dimension
    @State private var displayDim: WeatherDetailDimension = WeatherDetailDimension.allCases.first!

    var body: some View {
        ZStack(alignment: .top) {
            // Background gradient follows the *display* dimension (not raw page)
            dimensionBackground

            // ── Infinite-looping page view ──
            TabView(selection: $page) {
                ForEach(0..<Self.extended.count, id: \.self) { i in
                    DimensionPanelView(
                        dimension: Self.extended[i],
                        weather: weather,
                        detail: detail
                    )
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            .onChange(of: page) { newPage in
                // Update display dimension for background/indicator
                displayDim = Self.extended[newPage]
                // When hitting sentinel pages, snap to actual counterpart
                if newPage == 0 {
                    DispatchQueue.main.async {
                        page = Self.extended.count - 2   // last real page
                    }
                } else if newPage == Self.extended.count - 1 {
                    DispatchQueue.main.async {
                        page = 1                          // first real page
                    }
                }
            }

            // ── Top bar ──
            topBar

            // ── Indicator dots (only 4 dots) ──
            VStack {
                Spacer()
                indicatorDots
                    .padding(.bottom, 32)
            }
        }
        .preferredColorScheme(.dark)
        .ignoresSafeArea()
    }

    // MARK: - Sub-views

    private var dimensionBackground: some View {
        Group {
            switch displayDim {
            case .temperature:
                LinearGradient(colors: [Color(hex: 0x1A237E), Color(hex: 0x283593)],
                               startPoint: .top, endPoint: .bottom)
            case .wind:
                LinearGradient(colors: [Color(hex: 0x004D40), Color(hex: 0x00695C)],
                               startPoint: .top, endPoint: .bottom)
            case .precipitation:
                LinearGradient(colors: [Color(hex: 0x0D47A1), Color(hex: 0x1565C0)],
                               startPoint: .top, endPoint: .bottom)
            case .air:
                LinearGradient(colors: [Color(hex: 0x1B5E20), Color(hex: 0x2E7D32)],
                               startPoint: .top, endPoint: .bottom)
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.4), value: displayDim)
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.du(16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }
            Spacer()
            Text(displayDim.title)
                .font(.du(17, weight: .semibold))
                .foregroundColor(.white)
                .animation(.easeInOut(duration: 0.2), value: displayDim)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
        .padding(.top, 56)
    }

    /// 4 indicator dots mapping to the 4 real dimensions.
    private var indicatorDots: some View {
        HStack(spacing: 8) {
            ForEach(WeatherDetailDimension.allCases) { dim in
                Circle()
                    .fill(dim == displayDim ? Color.white : Color.white.opacity(0.35))
                    .frame(
                        width:  dim == displayDim ? 8 : 6,
                        height: dim == displayDim ? 8 : 6
                    )
                    .animation(.spring(response: 0.3), value: displayDim)
            }
        }
    }
}
