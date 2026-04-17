## Context

`WeatherSunBurstCore` 是纯数据枚举，负责所有 burst 相关的调优常量与映射函数。`WeatherSceneManager` 消费这些常量来构建射线节点（`makeSunBurstNode`）和驱动动画（`runSunBurstAnimation`）。`WeatherMainView` 在 `beginSunDetailPresentation()` 中同时触发音频和动画。

音频文件 `sun-detail-enter.wav`（622ms，16kHz，mono）经波形分析确认，振幅峰值出现在 **t=100ms**。

---

## Goals / Non-Goals

**Goals**
- 视觉 burst 第一帧与音频峰值对齐（误差 <20ms）
- 射线爆发中心偏移至太阳球体后方，形成日冕感
- 射线仅从太阳赤道边缘透出，射线不从太阳正面穿过
- 射线使用黑色与灰色混合（6:4）
- 射线动画仳点击太阳的腿追赶风格，远射答相遇后消失
- XY 平面每个方向均有射线覆盖

**Non-Goals**
- 不修改音频文件本身或音量
- 不影响 tap burst（`triggerDetailSunTapBurst`）逻辑

---

## Decisions

### 决策 1：Burst 触发时序拆分

**问题**：`runSunBurstAnimation()` 目前在 `startSunDetailTransition` 的 completion block（t≈500ms）中执行，而音频峰值在 t=100ms，两者错位约 420ms。

**决策**：将 `runSunBurstAnimation()` 从 completion block 中移出，在 `startSunDetailTransition` 内单独以 `asyncAfter(0.08s)` 触发。需新增属性 `private var burstAnimationWorkItem: DispatchWorkItem?` 存储该 work item，并在 `cancelPendingTransitionWork()` 中补充取消逻辑，确保中途退出不会残留 burst 触发。

```
t=0ms    音频开始 + startSunDetailTransition 开始
t=80ms   runSunBurstAnimation() 触发
t=100ms  burst 第一帧可见（80ms + 20ms burstDelay）≈ 音频峰值
t=500ms  completion block：pauseSunSpinAnimations + scheduleEntrySpinAnimation
```

burst 动画总时长约 380ms（fade in 40ms + hold + fade out 160ms），在 completion block 之前已自然结束，无依赖冲突。

**备选方案**：修改 `sunDetailTransitionDuration` 到 0.1s，让 completion block 更早执行。排除——过渡动画时长影响所有入场动画（镜头移动、太阳缩放、温度淡出），不能单独改。

---

### 决策 2：BurstNode Z 轴偏移

**问题**：`sunBurstNode` position = `(0, 0, 0)`（与 `sunAssembly` 同中心），前方射线直接覆盖太阳表面。

**决策**：在 `buildScene()` 中将 `burstNode.position` 设为 `(0, 0, burstZOffset)`，其中 `burstZOffset = -sunRadius * 0.5 ≈ -1.22`（负 Z = 远离相机）。

```
sunAssembly
├─ sunModelNode  z=0       半径 2.44，面向相机
└─ sunBurstNode  z=-1.22   爆发中心在太阳后方
                           → 前方射线从太阳边缘透出（日冕）
                           → 后方射线完全被太阳遮挡
```

新增常量到 `WeatherSunBurstCore`：
```swift
static let burstZOffset: Float = -1.22  // -sunRadius * 0.5
```

---

### 决策 3：射线颜色改为固定黑/灰混合

**原方案**：`colorWhite(forZ:)` 根据深度映射白色度，后方近白、前方近黑。  
改为仅后半球采样后，所有射线均处于 z ∈ [-1, 0]，深度函数不再适用。

**决策**：射线颜色改为每次触发时随机分配：60% 黑色（`UIColor.black`）/ 40% 灰色（`white: 0.55`）。不再使用深度映射函数决定颜色。

---

### 决策 4：射线分布改为仅后半球 + 均匀方位角

**原方案**：7:3 前偏采样，70% 前半球、30% 后半球。视觉上射线从太阳正面穿出，体验不好。

**决策**：仅在后半球采样（`u ∈ [-1, 0]`），所有射线方向 z ≤ 0，不会向相机方向延伸。方位角按索引均匀分布（`baseAzimuth = index / rayCount * 2π`），叠加 ±0.18 rad 抖动，确保 XY 平面所有方向均有射线覆盖。

```swift
let baseAzimuth = Float(index) / Float(rayCount) * Float.pi * 2
let azimuth = baseAzimuth + Float.random(in: -0.18 ... 0.18)
let u = Float.random(in: -1 ... 0)
```

后半球内使用 `colorZ = z * 2 + 1` 重映射到 [-1, +1]，供 `colorWhite`/`thickness`/`delayOffset` 使用：赤道（z=0 → colorZ=+1）近黑，深后（z=-1 → colorZ=-1）近白。

### 决策 5：动画改为 tap-burst 腿追赶风格

**问题**：原来的 fade-in/hold/fade-out + 平移缩放动画形式感弱，与点击太阳的互动动画风格不统一。

**决策**：射线采用和点击太阳相同的腿追赶风格：
- 前端（外端）：三次方 easeOut 向外飞出
- 后端（内端）：在 50% 进度后匹速追赶前端
- 两端相遇后线段消失

```
burstFlyDuration = 0.38s
tailFrac         = 0.50
flyDist          = outwardDistance(forLength) × 7
```

### 决策 6：太阳深度遮挡

**问题**：射线节点在 `sunBurstNode`（z=-1.22）下，但 SceneKit 默认渲染顺序可能导致射线透过太阳表面可见。

**决策**：
1. `sun.renderingOrder = -1`，`burstNode.renderingOrder = 0`：太阳先渲染并写入深度缓决，射线渲染时做深度测试被剔除
2. 太阳材质设置 `writesToDepthBuffer = true` / `readsFromDepthBuffer = true`，防止 SceneKit 因纹理 alpha 通道将其排入透明对象队列

---

## Risks / Trade-offs

| 风险 | 影响 | 缓解 |
|------|------|------|
| burst 与 completion block 并发执行 | 理论上 burst 动画可能被 `resetSunBurstState()` 中断 | completion block 不再调用 `runSunBurstAnimation`，`resetSunBurstState` 仅在新一轮 `startSunDetailTransition` 时执行，无冲突 |
| burstZOffset 导致射线起始点穿出太阳 | 短射线可能在太阳表面内起步 | 偏移量 -1.22 < sunRadius 2.44，射线仍从太阳表面附近出发，不会穿模 |
| 均匀方位角 + 后半球采样 每次结果不同 | ±0.18 抖动偶发导致相邻方向过近 | 20 条射线间隔 18°，最大抖动 ±10°，不会出现严重聚集 |
| flyDist × 7 使射线飞出屏幕外 | 长射线在场景边缘被裁剪 | 飞出后线段收尾消失，视觉上不突兀；必要时可降低倍数 |

---

## Migration Plan

无运行时迁移。修改仅限于常量和构建时逻辑，`buildScene()` 每次调用时重建所有节点，已有状态自动应用新值。

---

## Open Questions

- 音频触发延迟 80ms 是基于当前设备（模拟器/真机）的经验值，是否需要在低端设备上测试实际感知偏差？
