## 1. WeatherSunBurstCore 常量更新

- [x] 1.1 在 `WeatherSunBurstCore` 中新增 `burstZOffset: Float = -1.22` 常量
- [x] 1.2 将 `colorWhite(forZ:)` 的 lerp 参数从 `(0.55, 0.04)` 改为 `(0.85, 0.02)`

## 2. WeatherSceneManager — Burst 时序拆分

- [x] 2.0 在 `WeatherSceneManager` 中新增 `private var burstAnimationWorkItem: DispatchWorkItem?` 属性，并在 `cancelPendingTransitionWork()` 中补充 `burstAnimationWorkItem?.cancel(); burstAnimationWorkItem = nil`
- [x] 2.1 在 `startSunDetailTransition` 中，新增独立的 `DispatchWorkItem` 在 80ms 后调用 `runSunBurstAnimation()`，存入 `burstAnimationWorkItem`
- [x] 2.2 从 transition completion block（t≈500ms）中移除 `runSunBurstAnimation()` 调用

## 3. WeatherSceneManager — BurstNode Z 轴偏移

- [x] 3.1 在 `buildScene()` 的 transition 模式分支中，将 `burstNode.position` 设为 `SCNVector3(0, 0, WeatherSunBurstCore.burstZOffset)`

## 4. WeatherSceneManager — 射线分布偏置

- [x] 4.1 在 `makeSunBurstNode()` 中，将均匀球面采样 `u = Float.random(in: -1...1)` 替换为 7:3 前偏采样（70% 取 `[0,1]`，30% 取 `[-1,0)`）

## 5. SmokeTest 同步

- [x] 5.1 在 `WeatherSunBurstTransitionSmokeTests` 中新增断言，验证 `colorWhite(forZ: -1.0) ≥ 0.80`（后方近白）和 `colorWhite(forZ: 1.0) ≤ 0.05`（前方近黑）
- [x] 5.2 新增 smoke test 验证 `WeatherSunBurstCore.burstZOffset` 值为 `-1.22`（误差 < 0.01）

## 6. 验证

- [ ] 6.1 在真机上确认 burst 第一帧视觉感知与 `sun-detail-enter` 音频打击点对齐
- [ ] 6.2 确认射线仅从太阳赤道边缘透出，无射线从正面穿过太阳
- [ ] 6.3 确认黑色射线约占 60%、灰色射线约占 40%，颜色分布自然

## 7. 射线视觉精修（后续调优）

- [x] 7.1 将球面采样改为仅后半球（`u ∈ [-1, 0]`），避免射线向相机方向延伸穿透太阳正面
- [x] 7.2 在 `makeSunBurstRayNode` 和相关函数中，将后半球 z 重映射为 `colorZ = z * 2 + 1`，使赤道射线（z=0）→ 近黑，深后射线（z=-1）→ 近白
- [x] 7.3 方位角改为按索引均匀分布（`baseAzimuth = index / rayCount * 2π`），叠加 ±0.18 rad 随机抖动，确保每个方向都有射线
- [x] 7.4 将动画改为仿 tap-burst 风格：前端 easeOut 飞出（`flyDist × 7`），后端在 50% 进度后匀速追赶，两端相遇后线段消失（`burstFlyDuration = 0.38s`）
- [x] 7.5 射线颜色改为 60% 黑色 / 40% 灰色（`white: 0.55`），每次触发时随机分配，不再使用深度映射颜色
- [x] 7.6 在 `buildScene()` transition 模式中设置 `sun.renderingOrder = -1`、`burstNode.renderingOrder = 0`，在太阳材质设置 `writesToDepthBuffer = true` / `readsFromDepthBuffer = true`，确保太阳完全遮挡后方射线
