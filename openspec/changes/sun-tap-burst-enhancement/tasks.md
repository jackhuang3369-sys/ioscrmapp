## 1. 重构 makeSunBurstRayNode 支持随机化参数

- [x] 1.1 修改 `makeSunBurstRayNode` 签名，接受 `direction: SIMD3<Float>`、`length: Float`、`jitter: Float` 参数，移除对 `index` 和 `isFrontRay` 二值判断的依赖
	**必须保留**：在方法内仍以 `ObjectIdentifier(rayNode)` 为 key，向 `sunBurstRayDirections`、`sunBurstRayStartPositions`、`sunBurstRayBaseOpacities` 三个字典写入对应值（`resetSunBurstState()` 和 `runSunBurstAnimation()` 在运行时依赖这三个字典）
- [x] 1.2 实现起始位置 jitter：`distanceFromCenter = sunRadius * jitter + halfLength`
- [x] 1.3 实现 Z 深度连续颜色映射：`white = lerp(0.55, 0.04, (z+1)/2)`，`alpha = lerp(0.28, 0.92, (z+1)/2)`，替代 isFrontRay 二值着色
- [x] 1.4 实现厚度随深度连续变化：`thickness = lerp(0.038, 0.056, (z+1)/2)`
- [x] 1.5 将节点级 `rayNode.opacity` 统一设为 `1.0`，并将 `sunBurstRayBaseOpacities[id]` 也存为 `1.0`；深度感完全由材质 alpha（1.3 步）承载，避免材质 alpha 与节点 opacity 双重乘法导致后方射线过度透明

## 2. 重构 makeSunBurstNode 生成 20 条随机分布射线

- [x] 2.1 移除 hardcoded `directions` 数组，改为循环生成 20 条射线
- [x] 2.2 每条射线随机化参数：`azimuth = Float.random(in: 0 ..< 2 * .pi)`，`elevation = Float.random(in: -0.26 ... 0.26)`，由此推导单位方向向量
- [x] 2.3 长度按三档随机分配：短（`2.0–3.0`，约 20%）、中（`3.0–4.8`，约 60%）、长（`4.8–6.5`，约 20%）
- [x] 2.4 每条射线独立生成 jitter 因子 `Float.random(in: 0.95 ... 1.05)`

## 3. 重构 runSunBurstAnimation 实现按深度错帧和位移联动

- [x] 3.1 将每条射线按 Z 分量分为 4 层，各层 delay 依次为 0ms、15ms、30ms、45ms，替代当前 `index % 5 * burstStagger` 逻辑
- [x] 3.2 向外飞出距离与射线长度联动：`outwardDistance = lerp(0.5, 1.2, (rayLength - 2.0) / (6.5 - 2.0))`，其中 2.0 为最短长度下限，6.5 为最长长度上限，映射到 `[0.5, 1.2]` 区间
	射线长度通过 `(rayNode.geometry as? SCNBox)?.height ?? 3.0` 读取（射线几何为 SCNBox，height 对应长度轴）
- [x] 3.3 确保 sunBurstNode 整体淡入淡出逻辑（burstDelay、burstFlyDuration、burstFadeDuration）保持不变，仅修改单根射线 delay 和 outwardDistance 计算

## 4. 修改 runSunExpansionAnimation 实现 spring 过冲

- [x] 4.1 在 `runSunExpansionAnimation` 中将单一 `move(to: detailSunPosition)` 替换为 sequence：先 `move(to: overshootPosition, dur: 0.46, easeInEaseOut)` 再 `move(to: detailSunPosition, dur: 0.10, easeOut)`
- [x] 4.2 过冲位置定为 `SCNVector3(0, -0.22, -0.1)`（在终点 y=−0.04 基础上额外偏移 0.18，约 4% 全程）
- [x] 4.3 同步修改 scale 动画：先缩到 0.82，再弹回 0.84

## 5. 验证

- [ ] 5.1 在模拟器上触发太阳点击，目视确认：20 条射线方向随机、前排深色后排浅色、射线长短不一
- [ ] 5.2 目视确认太阳移动至中心时有轻微过冲弹回，弹回量不夸张
- [ ] 5.3 确认回程动画（退出第二屏）视觉无异常
- [x] 5.4 `xcodebuild` 编译通过，无警告新增

## 6. 最小自动化 smoke 覆盖

- [x] 6.1 在 `SmokeTests/` 中新增或扩展轻量 smoke 用例，断言 burst ray 数量恒为 20
- [x] 6.2 增加长度映射断言：`length=2.0 -> outwardDistance≈0.5`，`length=6.5 -> outwardDistance≈1.2`，且中间值单调递增
- [x] 6.3 增加 spring 分段时序断言：主段约 0.46s、回弹段约 0.10s，总时长约 0.56s
- [x] 6.4 增加 spring 终态断言：动画结束后位置收敛到 `detailSunPosition`，缩放收敛到 0.84
- [x] 6.5 将 6.1~6.4 用例纳入现有 smoke 运行命令，并在变更验证记录中保存一次成功执行证据
			- Automated evidence (2026-04-13):
				`swiftc -parse-as-library SmokeTests/WeatherSunBurstTransitionSmokeTests.swift ioscrmapp/Modules/Weather/SceneKit/WeatherSunBurstCore.swift -o /tmp/weather-sunburst-smoke && /tmp/weather-sunburst-smoke`
				-> `Weather sun burst transition smoke tests passed`
			- Automated evidence (2026-04-13):
				`swiftc SmokeTests/WeatherSpinInteractionSmokeTests.swift ioscrmapp/Modules/Weather/SceneKit/WeatherSpinCore.swift -o /tmp/weather-spin-smoke && /tmp/weather-spin-smoke`
				-> `Weather spin smoke tests passed`
			- Automated evidence (2026-04-13):
				`xcodebuild -project ioscrmapp.xcodeproj -scheme ioscrmapp-Develop -destination 'platform=iOS Simulator,name=iPhone 17' build`
				-> `BUILD SUCCEEDED`
