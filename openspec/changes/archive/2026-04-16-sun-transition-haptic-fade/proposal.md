## Why

点击太阳进入第二屏时，交互只有视觉和音效反馈，缺少触觉维度。加入与过渡动画同步的震动，可以让"太阳落位"这个关键时刻在感官上更完整、更有重量感。

## What Changes

- 新增 `WeatherSunTransitionHapticCore.swift`（纯常量枚举，放在 `SceneKit/`），定义震动的时长、起止强度、sharpness，以及线性插值函数 `intensity(at:)`。
- 新增 `WeatherHapticPlayer.swift`（单例，放在 `SceneKit/`），封装 CoreHaptics `CHHapticEngine`，提供 `prepareSunTransition()` 和 `playSunTransitionFade()` 两个方法。
- 修改 `WeatherMainView.swift`，在 `enterSunDetail()` 中预热引擎并触发震动：`prepareSunTransition()` 在 `prepareSunDetailTransition()` 之后调用，`playSunTransitionFade()` 与 `playSunDetailEnter()` 同步触发。
- 新增 `SmokeTests/WeatherSunTransitionHapticSmokeTests.swift`，验证强度线性映射的边界值与中点。

## Capabilities

### New Capabilities
- `sun-transition-haptic`: 点击太阳进入第二屏时的触觉反馈——CoreHaptics 连续震动，从 `t=0` 到 `t=500ms`，intensity 从 0.8 线性衰减至 0.1（保留余震），sharpness 恒为 0.5。

### Modified Capabilities

None.

## Impact

- 新增两个 Swift 文件：`WeatherSunTransitionHapticCore.swift`、`WeatherHapticPlayer.swift`，均在 `ioscrmapp/Modules/Weather/SceneKit/`。
- 修改 `WeatherMainView.swift`，仅在 `enterSunDetail()` 内追加两行调用，不改变现有调用顺序和状态机。
- 新增 `SmokeTests/WeatherSunTransitionHapticSmokeTests.swift`。
- 引入 CoreHaptics 框架（iOS 13+，项目最低部署目标已满足）。
- 不影响回程动画、音效系统、SceneKit 节点结构或任何公共接口。
- 在不支持 CoreHaptics 的设备上（iPhone 6s 及更早，无第二代 Taptic Engine），由 `supportsHaptics` 运行时判断，静默降级，不影响功能。
