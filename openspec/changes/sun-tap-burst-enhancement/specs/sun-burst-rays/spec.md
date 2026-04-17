## ADDED Requirements

### Requirement: Ray count and distribution
太阳爆发射线系统 SHALL 生成 20 条射线，方位角在 [0, 2π) 均匀随机分布，仰角在 ±15°（±0.26 rad）随机。

#### Scenario: Ray count
- **WHEN** 场景初始化构建 sunBurstNode
- **THEN** burstNode 包含恰好 20 条子节点

#### Scenario: Direction coverage
- **WHEN** 检查所有射线方向
- **THEN** 方位角覆盖 0 到 2π 全圆，无固定 hardcoded 方向列表

### Requirement: Ray start position jitter
每条射线的起始位置 SHALL 在太阳边缘 ±5% 半径范围内随机抖动（jitter 因子 [0.95, 1.05]）。

#### Scenario: Jitter range
- **WHEN** 计算任意射线起始距离
- **THEN** 起始距离 = sunRadius × jitter + halfLength，其中 jitter ∈ [0.95, 1.05]

#### Scenario: Sphere occludes inner portion of inset rays
- **WHEN** jitter < 1.0（射线近端落在球体表面内约 0.1 单位）
- **THEN** 太阳球体不透明材质自然遮挡内嵌部分，视觉上呈现射线从球面破出的效果，不露出穿透切面

### Requirement: Ray length distribution
射线长度 SHALL 按三档随机分布：短（约 20%，范围 2.0–3.0）、中（约 60%，范围 3.0–4.8）、长（约 20%，范围 4.8–6.5），单位与 SceneKit 世界坐标一致。

#### Scenario: Length variety
- **WHEN** 检查 20 条射线的 geometry height
- **THEN** 存在三个明显不同的长度区间，无所有射线等长的情况

### Requirement: Depth-based color mapping
射线颜色和透明度 SHALL 基于归一化 Z 分量连续映射：靠前（z ≈ +1）为深灰（white ≈ 0.04）高透明（alpha ≈ 0.92），靠后（z ≈ −1）为浅灰（white ≈ 0.55）低透明（alpha ≈ 0.28）。

#### Scenario: Front ray is dark
- **WHEN** 射线方向 z 分量接近 +1
- **THEN** 材质 diffuse white 值接近 0.04，材质 alpha 接近 0.92（节点级 opacity 统一为 1.0）

#### Scenario: Back ray is light
- **WHEN** 射线方向 z 分量接近 −1
- **THEN** 材质 diffuse white 值接近 0.55，材质 alpha 接近 0.28（节点级 opacity 统一为 1.0）

#### Scenario: No binary front/back split
- **WHEN** 检查 z 分量介于 −0.3 到 +0.3 的射线颜色
- **THEN** 颜色值为中间连续值，而非仅有两种固定颜色

### Requirement: Sun renders in front of rays
太阳球体 SHALL 在视觉上位于所有射线的前方，靠后射线被太阳遮挡。

#### Scenario: Sun occludes back rays
- **WHEN** 射线 z 分量为负（朝屏幕后方）
- **THEN** 太阳球体通过深度测试自然遮挡该射线穿过太阳区域的部分

### Requirement: Layered stagger by depth
射线播放错帧 SHALL 按 Z 深度分层：z > 0.4 的前排射线 delay = 0，依次各层增加约 15ms，最后排（z < −0.4）delay ≈ 45ms。

#### Scenario: Front rays fire first
- **WHEN** burst 动画开始
- **THEN** z > 0.4 的射线最先开始向外飞出，z < −0.4 的射线最后开始

### Requirement: Outward fly distance scales with length
每条射线向外飞出的位移 SHALL 通过线性插值与其长度联动，公式为 `lerp(0.5, 1.2, (length - 2.0) / (6.5 - 2.0))`，确保最短射线（2.0 单位）飞出约 0.5，最长射线（6.5 单位）飞出约 1.2。

#### Scenario: Short ray travels less
- **WHEN** 长度约为最小值（≈ 2.0）的射线执行 burst 动画
- **THEN** 向外位移约 0.5 单位（lerp 公式在 length=2.0 时精确等于 0.5）

#### Scenario: Long ray travels more
- **WHEN** 长度 > 4.8 的射线执行 burst 动画
- **THEN** 向外位移约 1.2 单位

### Requirement: Ray direction and position stored for animation use
每条射线的方向向量和初始位置 SHALL 在创建时存入对应字典（`sunBurstRayDirections`、`sunBurstRayStartPositions`、`sunBurstRayBaseOpacities`），以便 `resetSunBurstState()` 和 `runSunBurstAnimation()` 在动画执行和重置时能正确读取。

#### Scenario: Direction lookup returns correct vector
- **WHEN** 通过 `rayDirection(for: rayNode)` 读取任意射线方向
- **THEN** 返回该射线创建时使用的方向向量，而非默认值 `(0, 1, 0)`

#### Scenario: Position reset restores to original
- **WHEN** 调用 `resetSunBurstState()` 后检查任意射线 position
- **THEN** 射线 position 恢复为创建时写入 `sunBurstRayStartPositions` 的初始位置
