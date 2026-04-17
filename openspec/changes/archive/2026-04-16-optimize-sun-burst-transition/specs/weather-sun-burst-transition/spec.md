## ADDED Requirements

### Requirement: Burst 动画与音频峰值时序对齐
`runSunBurstAnimation()` SHALL 在 `startSunDetailTransition` 启动后约 80ms 触发，使 burst 第一帧（80ms + 20ms burstDelay = 100ms）与 `sun-detail-enter.wav` 振幅峰值（t=100ms）在感知上对齐。

#### Scenario: burst 提前触发，不等待 transition 完成
- **WHEN** `startSunDetailTransition` 被调用
- **THEN** 系统在 80ms 后独立触发 `runSunBurstAnimation()`，不在 transition completion block 内执行

#### Scenario: completion block 仍执行收尾逻辑
- **WHEN** `startSunDetailTransition` 的 completion block 在 t≈500ms 执行
- **THEN** 系统执行 `pauseSunSpinAnimations` 和 `scheduleEntrySpinAnimation`，不再重复调用 `runSunBurstAnimation`

#### Scenario: 中途取消不留残留 burst
- **WHEN** `startSunDetailTransition` 启动后，在 80ms 前调用 `cancelPendingTransitionWork()`
- **THEN** 80ms 的 burst dispatch 不会执行（work item 已取消）

### Requirement: BurstNode 位于太阳球体后方
`sunBurstNode` 的 Z 坐标 SHALL 偏移为 `WeatherSunBurstCore.burstZOffset`（约 -1.22），使爆发中心位于太阳球体内部偏后，前方射线从太阳边缘透出形成日冕效果。

#### Scenario: burstNode 挂载时应用 Z 偏移
- **WHEN** `buildScene()` 在 transition 模式下构建场景
- **THEN** `sunBurstNode.position` 为 `SCNVector3(0, 0, WeatherSunBurstCore.burstZOffset)`，不再为零点

#### Scenario: burstZOffset 常量值
- **WHEN** 读取 `WeatherSunBurstCore.burstZOffset`
- **THEN** 值为 `-1.22`（等于 `-sunRadius * 0.5`，精度误差 < 0.01）

### Requirement: 射线颜色为黑/灰固定混合
`runSunBurstAnimation()` 中每条射线 SHALL 在触发时随机分配颜色：60% 为纯黑（`UIColor.black`），40% 为中灰（`white: 0.55`）。颜色不再基于深度映射。

#### Scenario: 60% 黑色 / 40% 灰色分配
- **WHEN** `runSunBurstAnimation()` 触发
- **THEN** 每条射线以 60% 概率分配黑色，40% 概率分配灰色，颜色在 `SCNAction` 执行前写入 `material.diffuse.contents`

#### Scenario: colorZ 重映射保持厚度/延迟层次
- **WHEN** 后半球射线（`z ∈ [-1, 0]`）的 `thickness` 和 `delayOffset` 被计算
- **THEN** 使用 `colorZ = z * 2 + 1` 将 z 映射至 `[-1, +1]`，使赤道射线（z=0）最厚最早、深后射线（z=-1）最细最晚

### Requirement: 射线分布为仅后半球 + XY 均匀方位角
`makeSunBurstNode()` 中的球面采样 SHALL 使所有射线落在后半球（z ≤ 0），方位角按索引均匀分布并叠加随机抖动，确保 XY 平面每个方向均有射线。

#### Scenario: 所有射线在后半球
- **WHEN** 生成 20 条射线
- **THEN** 所有射线方向 z ≤ 0（无射线朝向相机方向飞出）

#### Scenario: XY 平面方向均匀覆盖
- **WHEN** 生成 20 条射线
- **THEN** 方位角以 `index / rayCount * 2π` 为基准均匀分布，每条射线叠加 ±0.18 rad 随机抖动

### Requirement: 射线动画为 tap-burst 追赶风格
`runSunBurstAnimation()` SHALL 使用前端 easeOut 飞出 + 后端追赶的线段动画，两端相遇后线段消失，不使用整体 fade-in/hold/fade-out。

#### Scenario: 前端 easeOut 飞出
- **WHEN** 射线动画触发
- **THEN** 前端以三次方 easeOut 向外飞出，总行程为 `outwardDistance × 7`

#### Scenario: 后端追赶并收尾
- **WHEN** 动画进度达到 50%
- **THEN** 后端开始匀速追赶前端；两端距离 ≤ 0.05 时线段 opacity = 0（消失）

### Requirement: 太阳完全遮挡后方射线
`buildScene()` transition 模式 SHALL 设置 `sun.renderingOrder = -1` 及太阳材质 `writesToDepthBuffer = true`，确保太阳表面在深度上完全遮挡 z < 0 的射线。

#### Scenario: 太阳先于射线写入深度缓冲
- **WHEN** SceneKit 渲染 transition 场景
- **THEN** `sun.renderingOrder (-1) < burstNode.renderingOrder (0)`，太阳先占深度，射线做深度测试后被裁剪

#### Scenario: 太阳材质不透明写入深度
- **WHEN** 渲染太阳材质
- **THEN** `writesToDepthBuffer = true` 且 `readsFromDepthBuffer = true`，纹理 alpha 通道不影响深度写入
