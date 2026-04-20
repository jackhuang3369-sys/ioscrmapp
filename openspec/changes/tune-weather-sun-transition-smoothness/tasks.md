## 1. 参数与曲线调整

- [ ] 1.1 将 `sunDetailTransitionDuration` 调整到 0.35~0.40（建议从 0.38 开始）
- [ ] 1.2 将 `sunReturnTransitionDuration` 调整到 0.20~0.25（建议从 0.22 开始）
- [ ] 1.3 将 `alignDisplayGroupToFrontForDetail` 默认时长调整到 0.10~0.14（建议从 0.12 开始），并**将正面容忍度从 8° 放宽到 15°~20°**（减少进入前对齐触发概率）；对齐完成后通过 `completion` 回调触发主转场，而非两段独立动画系统竞争；**safety net timeout 应略大于声明的 0.12s（如 0.15s）**，防止 SCNTransaction completion block 触发时机略晚于动画结束
- [ ] 1.4 将主运动相关的 `easeInEaseOut`/`easeInOutCubic` 调整为更"前快后稳"的曲线：
  - **注意**：SCNAction.timingMode 只支持 `easeIn`/`easeOut`/`linear`/`easeInEaseOut`，不支持 cubic 变体
  - 当前 `makeScaleAction` 中的 `easeInOutCubic` 是通过 `SCNAction.customAction` + 自定义函数实现的
  - 曲线调整应通过 `CAMediaTimingFunction(name: .easeOut)` 或等效自定义函数实现
  - 如引入 spring，**settle 时间不超过总时长的 30%，且不得出现第二次可见振荡**
- [ ] 1.5 在调整前，找到 `WeatherSunTransitionHapticCore` 的 `totalDuration` 实际值，确保与新的主转场时长（约 0.38s）对齐

## 2. SwiftUI / SceneKit 时间线对齐

- [ ] 2.1 统一第二屏 overlay 的显隐节奏：进入时**立即置 `isSunDetailPresented = true`**（结构瞬间完整出现），同时 `detailOverlayOpacity` 从 0 在 ~0.22~0.26s 内完成渐显；避免多段串行动画（0.42 + 0.08 + 0.34）
- [ ] 2.2 **注意**：面板内容（温度、按钮等）应使用各自独立的渐显动画（如 `opacity 0→1, duration 0.25s, delay 0.05s`），而非整体一次性闪现，确保不出现"UI 闪现"感
- [ ] 2.3 检查 `alignDisplayGroupToFrontForDetail`（SCNTransaction）与 `startSunDetailTransition`（SCNAction）是否存在动画系统竞争——确保主转场在预对齐 `completion` 回调内启动，而非并行竞争

## 3. 标题节奏

- [ ] 3.1 提前 `SUN` 标题 reveal 的 delay，从当前 `0.6 × duration`（主运动 60% 处）调整到 `0.15~0.20 × duration`（主运动 15~20% 处）；reveal 时长从 `0.3 × duration` 缩短到 `0.2 × duration`
- [ ] 3.2 确保标题与其他 UI 元素（温度、按钮）的出场顺序和节奏协调，避免标题"跟不上点击"

## 4. 返回转场

- [ ] 4.1 对 `startReturnToMainTransition` 做同等分析——当前 `sunReturnTransitionDuration = 0.2s`，调整到 0.22s 后仍需验证返回时是否"够跟手"
- [ ] 4.2 确认 `alignDetailSceneToFront` 和 `applyDisplayGroupRotation` 无隐式动画——当前 `exitSunDetail` 中 `alignDetailSceneToFront` 使用 `applyDisplayGroupRotation(transitionRestRotation)`（直接赋值），不会引入延迟；如发现某处被误用为动画版本，需修复

## 5. 触觉/音效对齐

- [ ] 5.1 将太阳转场触觉总时长与主转场对齐（约 0.35~0.40s），burst 仍可略提前（对齐 `runSunBurstAnimation` 的 0.08s 延迟），但不延长整体感知时长
- [ ] 5.2 验证 `WeatherAudioPlayer.shared.playSunDetailEnter()` 的音频峰值时长是否与新时长兼容

## 6. 第二屏点击太阳射线速度（新增）

- [ ] 6.1 将 `WeatherSunDetailTapBurstCore.totalDuration` 从 **1.0s 缩短到 0.50s**，使射线爆发更快、更跟手
- [ ] 6.2 将 `WeatherSunDetailTapBurstCore.tailStartFraction` 从 **0.30 调整到 0.20**，让尾部更早追赶，射线收缩更有力度感
- [ ] 6.3 **验证**：修改后最后一条射线结束时间从约 1.228s 缩短到约 0.728s，整体节奏更紧凑
- [ ] 6.4 **注意**：easeOut 曲线形状不变（`1-(1-t)³`），仅时间减半；如仍觉得不够快，可考虑增大 `tapOutwardDistance`（当前 0.7）让射线飞更远

## 7. 验证与回归

- [ ] 7.1 在小屏与大屏设备验证：进入/返回/快速点击节流/无拖尾与无卡住
- [ ] 7.2 记录关键体感指标：点击到"可交互"的时间显著降低；转场无明显分段
- [ ] 7.3 验证快速连点场景（点击→返回→点击）下，`isSunTransitionActive` 状态机能正确节流，无状态残留
- [ ] 7.4 验证第二屏点击太阳时射线速度明显加快，爆发感更强
