## Context

点击太阳进入第二屏时，当前只有视觉（射线爆发、太阳移动）和音效（sun-detail-enter.wav）两个感官通道。引入触觉反馈需要决定：用什么 API、震动曲线如何定义、如何与现有时序对齐、以及在哪个层触发。

项目中已有两处触觉反馈先例：
- `WeatherHourlyStrip` 使用 `UISelectionFeedbackGenerator`（离散脉冲，用于滑动刻度）
- `AIChatView` 使用 `UIImpactFeedbackGenerator`（单次冲击，用于按钮）

两者均为一次性或离散型触觉。本次需要的是 500ms 连续衰减型触觉，与上述方案性质不同。

## Goals / Non-Goals

**Goals:**
- 实现从 `t=0`（点击太阳）到 `t=500ms`（太阳落位）的连续震动
- 震动 intensity 从 0.8 线性衰减至 0.1，sharpness 恒为 0.5
- 与 `playSunDetailEnter()` 在同一帧触发，感官对齐
- 在不支持 CoreHaptics 的设备上静默降级

**Non-Goals:**
- 回程动画不触发震动
- 不对 `triggerDetailSunTapBurst()`（第二屏连续点击）添加触觉
- 不影响 `WeatherHourlyStrip` 或其他已有触觉系统

## Decisions

### 决策 1：使用 CoreHaptics 而非 UIImpactFeedbackGenerator

**选择**：`CHHapticEngine` + `CHHapticEvent(.hapticContinuous)` + `parameterCurve`

**理由**：`UIImpactFeedbackGenerator` 只能产生离散脉冲（heavy/medium/light），无法实现连续曲线衰减。CoreHaptics 的 `parameterCurve` 可以在任意时间点精确指定 intensity，是唯一能做到"线性由强到弱"的方案。

**备选方案**：定时器每 50ms 触发一次 UIImpactFeedback，分档递减强度——但这是"模拟连续"，视觉上可能感知到颗粒感，且定时精度依赖主线程调度。

---

### 决策 2：纯常量枚举 WeatherSunTransitionHapticCore 与播放器分离

**选择**：`WeatherSunTransitionHapticCore`（枚举，纯常量 + 纯函数）独立于 `WeatherHapticPlayer`（单例，持有 CHHapticEngine）。

**理由**：与项目中 `WeatherSunBurstCore`、`WeatherSunTapAudioCore` 等的模式完全一致。纯常量层可以独立编译运行 smoke test，无需 UIKit/CoreHaptics 依赖，验证线性映射逻辑不依赖真实设备。

---

### 决策 3：触发点在 WeatherMainView 而非 WeatherSceneManager

**选择**：在 `WeatherMainView.enterSunDetail()` 中调用 `WeatherHapticPlayer.shared.prepareSunTransition()` 和 `playSunTransitionFade()`，与 `WeatherAudioPlayer` 触发位置对称。

**理由**：触觉反馈是 UI 层行为，不属于 3D 场景管理职责。`WeatherSceneManager` 管理 SceneKit 节点与动画，不应感知触觉。`WeatherMainView` 已经是音效触发点，对称地放在这里维护成本最低，也符合关注点分离原则。

---

### 决策 4：震动参数

| 参数 | 值 | 理由 |
|------|-----|------|
| startIntensity | 0.8 | 最大值 1.0 太猛，0.8 有力但不激进 |
| endIntensity | 0.1 | 保留余震感，0.0 骤停显得突兀 |
| sharpness | 0.5 | 中等，给人"厚重"感而非"尖锐"刺激 |
| totalDuration | 0.5 | 严格等于 sunDetailTransitionDuration |

---

### 决策 5：CHHapticEngine 放在 SceneKit/ 目录

**选择**：`WeatherHapticPlayer.swift` 和 `WeatherSunTransitionHapticCore.swift` 均放在 `ioscrmapp/Modules/Weather/SceneKit/`。

**理由**：`WeatherAudioPlayer.swift` 已在该目录，触觉播放器与音频播放器职责平行，放在一起便于维护。未来若有多处触觉需求，届时再提取公共层。

## Risks / Trade-offs

**[风险] CHHapticEngine 冷启动延迟约 100ms**  
→ 缓解：在 `prepareSunDetailTransition()` 阶段（用户点击前已预备好 SceneKit）同步调用 `prepareSunTransition()`，提前预热引擎，确保 `playSunTransitionFade()` 触发时引擎已就绪。

**[风险] 部分旧设备（iPhone 6s 及更早，无第二代 Taptic Engine）不支持 CHHapticEngine**  
→ 缓解：`CHHapticEngine.capabilitiesForHardware().supportsHaptics` 返回 false 时静默跳过，不影响任何功能。无需人工判断设备型号，完全由运行时能力检测处理。

**[风险] 用户快速多次点击太阳（连续触发）**  
→ 缓解：每次 `playSunTransitionFade()` 前先 stop 上一次 pattern player，与 `enterSunDetail()` 已有的 `isSunTransitionActive` guard 保持逻辑一致。

**[Trade-off] CoreHaptics 无法在 Simulator 上产生实际震动**  
→ 接受：Smoke test 只验证常量层纯函数（intensity 映射），不依赖真实 Taptic Engine，已有充分覆盖。目视/触觉验证在真机上进行。
