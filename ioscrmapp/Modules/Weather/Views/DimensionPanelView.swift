import SwiftUI
import SceneKit

// MARK: - DimensionPanelView（单个维度面板：上 2/3 场景 + 下 1/3 数据）

struct DimensionPanelView: View {
    let dimension: WeatherDetailDimension
    let weather: CurrentWeather
    let detail: WeatherDetailData

    @State private var cachedScene: SCNScene?

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // ── 上 2/3：3D 场景区（Phase 4 替换为 DimensionSceneBuilder 构建的 SceneKit 场景） ──
                dimensionSceneArea
                    .frame(height: geo.size.height * 2 / 3)

                // ── 下 1/3：数据展示区 ──
                DimensionDataView(
                    dimension: dimension,
                    weather: weather,
                    detail: detail
                )
                .frame(height: geo.size.height / 3)
                .background(Color.black.opacity(0.25))
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - 3D Scene Area

    @ViewBuilder
    private var dimensionSceneArea: some View {
        ZStack {
            if let scene = cachedScene {
                WeatherSceneView(scene: scene, manager: nil)
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            guard cachedScene == nil else { return }
            cachedScene = DimensionSceneBuilder.buildScene(for: dimension, data: detail)
        }
    }
}
