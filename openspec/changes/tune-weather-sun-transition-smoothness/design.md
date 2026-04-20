## 背景

当前"点太阳进第二屏"的体验存在三类不流畅来源：时长叠加（预对齐 + 主转场）、缓动曲线偏肉（大量 `easeInEaseOut`）、以及 SwiftUI overlay 与 SceneKit 转场不同步（面板露出拖尾、标题慢半拍）。

此外，第二屏点击太阳的射线爆发速度偏慢（totalDuration 1.0s），与 No Boring Weather 相比显得不够干脆。

## 设计决策

- **总时长收敛**：将主转场时长从 0.5s 下调到约 0.38s；返回从 0.2s 微调到约 0.22s（避免过硬）。
- **预对齐弱化 + 动画系统隔离**：缩短 `alignDisplayGroupToFrontForDetail` 到约 0.12s，放宽正面容忍度从 8° 到 15°~20°；**关键：主转场必须在预对齐的 `completion` 回调内启动**，而非与 SCNTransaction 并行竞争，确保两段不叠加。
  - **注意**：SCNTransaction completion block 在下一个渲染帧触发，略晚于动画实际结束时间；safety net timeout 应设置为声明时长的 ~1.25 倍（如 0.12s 声明 → 0.15s safety net）。
- **曲线策略**：主视觉运动（太阳位移/场景推进/相机推进/旋转回正）采用 **前快后稳** 的 ease-out 曲线：
  - **技术说明**：SCNAction.timingMode 只支持 `easeIn`/`easeOut`/`linear`/`easeInEaseOut`，不支持 cubic 变体。当前 `makeScaleAction` 中的 `easeInOutCubic` 是通过 `SCNAction.customAction` + 自定义函数实现的。曲线调整应通过 `CAMediaTimingFunction(name: .easeOut)` 或等效自定义函数实现。
  - 缩放可保留轻微弹性（spring），但 **settle 时间不超过总时长的 30%，且不得出现第二次可见振荡**。
- **统一时间线 + 防闪现**：SwiftUI 叠层进入第二屏时**立即置 `isSunDetailPresented = true`**（结构瞬间完整出现），`detailOverlayOpacity` 在 ~0.22~0.26s 内完成渐显；同时面板内部各子视图（温度数值、操作按钮等）使用各自独立的 `opacity 0→1, duration 0.25s, delay 0.05s` 渐显，避免整体闪现感。**不再使用** 原来的 0.42s easeInOut + 0.08s 延迟 + 0.34s easeOut 多段串联。
- **标题提前**：`SUN` 等关键标题 reveal delay 从 `0.6 × duration` 调整到 `0.15~0.20 × duration`，reveal 时长从 `0.3 × duration` 缩短到 `0.2 × duration`，确保"跟手"。
- **返回转场同等处理**：返回时 `detailOverlayOpacity` 渐隐时长（当前 0.24s）需与 SceneKit 返回时长（约 0.22s）匹配；`alignDetailSceneToFront` 使用 `applyDisplayGroupRotation` 直接赋值（无动画），不引入额外延迟。
- **触觉/音效对齐**：触觉总时长与视觉主转场一致（约 0.38s），burst 仍可略提前（对齐 `runSunBurstAnimation` 的 0.08s 延迟），不延长整体感知时长。
- **第二屏点击射线加速**：将 `WeatherSunDetailTapBurstCore.totalDuration` 从 **1.0s 缩短到 0.50s**，`tailStartFraction` 从 **0.30 调整到 0.20**：
  - easeOut 曲线形状不变（`1-(1-t)³`），仅时间减半，速度加倍
  - 尾部更早追赶（20% vs 30%），射线收缩更有力度感
  - 最后一条射线结束时间从约 **1.228s 缩短到约 0.728s**（改善 40%）
  - 如仍觉得不够快，可增大 `tapOutwardDistance`（当前 0.7）让射线飞更远

## 数据流 / 时序（高层）

**入场（优化后）：**
```
t=0:      用户点击太阳
t=0~0.12: 必要时预对齐（SCNTransaction，easeOut）
t=~0.12:  预对齐 completion 回调触发主转场（block 在下一帧触发，约 0.12~0.15s）
t=~0.12:  SwiftUI: isSunDetailPresented = true（立即）
t=~0.12:  SceneKit: startSunDetailTransition() 开始（SCNAction，easeOut，~0.38s）
t=~0.12:  detailOverlayOpacity 从 0 渐显（0.22~0.26s）
t=~0.19:  标题开始出现（~0.12 + 0.07）
t=~0.50:  SceneKit 主转场完成（考虑 block 延迟，略晚于 0.38s）
t=~0.52:  overlay 稳定，进入可交互
```

**入场（最坏情况，不正面 + 预对齐触发）：**
```
t=0:      点击 → 预对齐开始
t=~0.15:  预对齐完成（含 SCNTransaction block 延迟）→ 主转场开始
t=~0.53:  总完成（~0.15 + 0.38，仍小于原 0.74s）
```

**第二屏点击射线（优化后）：**
```
t=0:       第一条射线开始（easeOut over 0.50s）
t=0.1s:    尾部开始追赶
t=0.228s:  最后一条射线开始（stagger 延迟）
t=0.50s:   第一条射线完成（头尾汇合）
t=0.728s:  最后一条射线完成（全部结束）
  vs 原：1.228s（改善 40%）
```

## 错误与降级

- 若某段动画无法按预期完成（或被中途退出），应确保状态机回到一致状态：`isSunTransitionActive` 清零、overlay opacity 归位、SceneKit 节点不残留未清理动作。
- `alignDisplayGroupToFrontForDetail` 的 `completion` 必须保证被调用，无论 SCNTransaction 是否完成；safety net timeout 应设置为声明时长的 ~1.25 倍（如 0.15s）。
- 快速连点时 `isSunTransitionActive` 必须正确阻止重入，避免状态机错乱。
- 如引入 spring 动画导致可见 overshoot 或多次振荡，应回退到纯 easeOut 方案。
- 如射线 0.50s 仍显得不够快，可增大 `tapOutwardDistance` 而非继续缩短 duration（避免射线"一闪而过"）。

## 测试与验证

- 在小屏与大屏模拟器/真机验证：点击太阳入场、返回、快速连点被正确节流、无 UI 拖尾。
- 记录主观体验：从点击到"可交互"时间（含预对齐时）< 0.58s（考虑 SCNTransaction block 延迟）。
- 验证 SwiftUI 面板无"闪现"感——面板结构瞬间出现但内容有层次渐显。
- 验证 SCNTransaction + SCNAction 竞争问题已修复：不再出现"两段动画叠加导致远超 0.38s"的情况。
- 验证 spring 动画 settle 时间 < 总时长的 30%，无第二次可见振荡。
- 验证第二屏点击太阳时射线速度明显加快，爆发感更强；最后一条射线在 0.728s 内完成。

## 发布策略

仅参数与时序调整，优先通过 Smoke/回归验证后合入；如观感不佳可快速回退到旧参数（不涉及资源与结构迁移）。
