## 1. 新增 WeatherSunTransitionHapticCore（纯常量层）

- [x] 1.1 在 `ioscrmapp/Modules/Weather/SceneKit/` 下新建 `WeatherSunTransitionHapticCore.swift`，定义 `enum WeatherSunTransitionHapticCore`，包含常量：`totalDuration: TimeInterval = 0.5`、`startIntensity: Float = 0.8`、`endIntensity: Float = 0.1`、`sharpness: Float = 0.5`
- [x] 1.2 在 `WeatherSunTransitionHapticCore` 中实现 `intensity(at t: TimeInterval) -> Float`：线性插值 `lerp(startIntensity, endIntensity, clamped(t / totalDuration, 0, 1))`，返回值 clamped 到 `[endIntensity, startIntensity]`

## 2. 新增 WeatherHapticPlayer（CoreHaptics 播放器）

- [x] 2.0 确认 `ioscrmapp.xcodeproj` 是否自动 glob `SceneKit/` 目录下的新文件；若否，在 Xcode 中将 `WeatherSunTransitionHapticCore.swift` 和 `WeatherHapticPlayer.swift` 加入 ioscrmapp target（Build Phases → Compile Sources）
- [x] 2.1 在 `ioscrmapp/Modules/Weather/SceneKit/` 下新建 `WeatherHapticPlayer.swift`，定义 `final class WeatherHapticPlayer`，含 `static let shared = WeatherHapticPlayer()`，import CoreHaptics
- [x] 2.2 在 `WeatherHapticPlayer` 中声明 `private var engine: CHHapticEngine?` 和 `private var currentPlayer: CHHapticPatternPlayer?`
- [x] 2.3 实现 `func prepareSunTransition()`：若 `CHHapticEngine.capabilitiesForHardware().supportsHaptics` 为 false 则直接返回；否则懒惰初始化 `engine`，调用 `engine?.start(completionHandler:)` 预热（错误静默忽略）
- [x] 2.4 实现 `func playSunTransitionFade()`：
  - 若 engine 为 nil 或不支持 haptics，直接返回
  - 先停止 `currentPlayer`（`try? currentPlayer?.stop(atTime: .now())`），置 nil
  - 构造 `CHHapticEvent(.hapticContinuous)`：duration = `WeatherSunTransitionHapticCore.totalDuration`，初始 intensity = `startIntensity`，sharpness = `sharpness`
  - 构造 intensity `parameterCurve`：起点 `(time: 0, value: startIntensity)`，终点 `(time: totalDuration, value: endIntensity)`
  - 创建 `CHHapticPattern`，通过 `engine?.makePlayer(with:)` 生成 player，赋值给 `currentPlayer`
  - 调用 `try? currentPlayer?.start(atTime: .now())`
  - 所有 `try?` 错误静默忽略

## 3. 修改 WeatherMainView 触发触觉

- [x] 3.1 在 `WeatherMainView.enterSunDetail()` 中，在 `sceneManager.prepareSunDetailTransition(...)` 调用之后、`sceneManager.startSunDetailTransition(...)` 之前，插入 `WeatherHapticPlayer.shared.prepareSunTransition()`
- [x] 3.2 在 `WeatherMainView.enterSunDetail()` 中，在 `WeatherAudioPlayer.shared.playSunDetailEnter()` 同一行之后（同帧），插入 `WeatherHapticPlayer.shared.playSunTransitionFade()`

## 4. 新增 Smoke Test

- [x] 4.1 在 `SmokeTests/` 下新建 `WeatherSunTransitionHapticSmokeTests.swift`，实现 `struct WeatherSunTransitionHapticSmokeTests`，包含 `static func run() throws` 入口
- [x] 4.2 断言 `t=0` 时 intensity ≈ 0.800（误差 < 0.001）
- [x] 4.3 断言 `t=0.25`（中点）时 intensity ≈ 0.450（误差 < 0.001），验证线性
- [x] 4.4 断言 `t=0.5`（终点）时 intensity ≈ 0.100（误差 < 0.001）
- [x] 4.5 断言 `t < 0`（边界下溢）clamp 到 startIntensity（≈ 0.800）
- [x] 4.6 断言 `t > totalDuration`（边界上溢）clamp 到 endIntensity（≈ 0.100）
- [x] 4.7 断言 `WeatherSunTransitionHapticCore.totalDuration == 0.5`，确保常量值未被意外修改
        **注**：此值须与 `WeatherSceneManager.sunDetailTransitionDuration`（同为 0.5）手动保持同步；不在 smoke test 中直接引用 `WeatherSceneManager` 以避免引入 SceneKit/UIKit 依赖导致独立编译失败

## 5. 验证

- [x] 5.1 运行 smoke test 编译命令：`swiftc -parse-as-library SmokeTests/WeatherSunTransitionHapticSmokeTests.swift ioscrmapp/Modules/Weather/SceneKit/WeatherSunTransitionHapticCore.swift -o /tmp/haptic-smoke && /tmp/haptic-smoke`，确认输出 `passed`
- [x] 5.2 `xcodebuild` 编译通过，无警告新增
- [ ] 5.3 在真机上点击太阳，感受震动从强到弱线性衰减、落位时余震自然消散
