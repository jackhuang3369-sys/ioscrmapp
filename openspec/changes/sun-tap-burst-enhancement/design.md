## Context

`WeatherSceneManager` 中的 `makeSunBurstNode()` 当前生成 12 条固定方向的射线，方向来自 hardcoded SIMD3<Float> 列表。颜色区分简单二值化（`isFrontRay` 判断），缺乏连续深度感。`runSunExpansionAnimation()` 使用 `.easeInEaseOut` 曲线将太阳移到中心，无弹性感。

改动范围严格限于 `WeatherSceneManager.swift` 的四个私有方法，不触碰公共接口、场景层级或其他动画系统。

## Goals / Non-Goals

**Goals:**
- 用随机分布的 20 条射线替代 12 条 hardcoded 射线
- 射线颜色和透明度基于 Z 深度连续映射，实现视觉层次
- 射线起始位置在太阳边缘 ±5% 半径范围内随机抖动
- 射线长度三档随机分布，向外飞出距离与长度联动
- 射线播放按 Z 深度分层错帧，强化前后层次
- 太阳入场动画改为微量过冲（约 4%）+ 弹回的 spring 效果

**Non-Goals:**
- 不修改场景层级、节点命名、公共接口
- 不影响回程动画（return transition）
- 不引入新的 SceneKit 节点类型或外部依赖
- 不修改 CALayer/CASpringAnimation，全程用 SCNAction 实现

## Decisions

### 1. 射线生成：随机 vs hardcoded

选择在 `buildScene()` 调用时一次性随机生成，结果固定（非每次点击重新随机）。理由：产品体验可预期，QA 可复现，视觉上每次进入天气页一致。替代方案（每次点击随机）动感更强但不稳定，不选。

射线数量定为 20 条：当前 12 条视觉密度略稀，24 条开始在旋转时显得堆叠，20 条是平衡点。

随机分布策略：
```
azimuth = Float.random(in: 0 ..< 2 * .pi)   // 水平方向均匀分布
elevation = Float.random(in: -0.26 ... 0.26) // ±15° 仰角（弧度）
```
由 azimuth + elevation 推导单位向量，替代 hardcoded 列表。

### 2. Z 深度颜色映射

将归一化 Z 分量（−1 到 +1）映射到颜色与透明度：

```
z in [-1, 1]
white  = lerp(0.55, 0.04, (z + 1) / 2)   // 靠前(z=+1)→0.04暗 / 靠后(z=-1)→0.55亮
alpha  = lerp(0.28, 0.92, (z + 1) / 2)   // 靠前→高不透明  / 靠后→低不透明
```

替代方案（保留二值 isFrontRay 判断）视觉跳跃，被放弃。

### 3. 起始位置抖动

`jitter = Float.random(in: 0.95 ... 1.05)`，起始距离 = `sunRadius * jitter + halfLength`。

±5% 相当于 ±0.12 单位（sunRadius=2.44）。注意：当 jitter < 1.0 时，射线近端（distanceFromCenter - halfLength = sunRadius × jitter ≈ 2.318 at min）会落在球体表面（≈2.42）以内，但球体的不透明材质会将该内嵌部分自然遮挡。视觉上表现为射线"从球面内部破出"，是预期的美术效果而非 bug，同时 ±5% 范围使整体破出感足够微妙。若未来评审认为内嵌不可接受，可将 jitter 范围调整为 [1.0, 1.1]。

### 4. Spring 过冲实现

使用 `SCNAction.sequence` 模拟，不引入 `CASpringAnimation`，保持动画系统统一：

```
detailSunPosition   = SCNVector3(0, -0.04, -0.1)  // 终点
overshootPosition   = SCNVector3(0, -0.22, -0.1)  // 微量过冲（差值 0.18，约4%全程）

sequence:
  [move(to: overshoot, dur: 0.46, easeInEaseOut),
   move(to: detail,    dur: 0.10, easeOut)]
```

Scale 同步：先到 0.82（轻微多缩），再弹回到 0.84。

CASpringAnimation 替代方案：需要绕过 SCNAction 系统直接操作 presentation layer，增加与现有动画协调的复杂度，不值得为轻微弹回效果引入。

### 5. 射线按深度错帧

将 20 条射线按 Z 分量分为 4 层（各延迟 0、15ms、30ms、45ms），替代当前 `index % 5 * stagger` 方案。当前方案与深度无关，此方案让"前排"射线稍早出现，视觉上更立体。

## Risks / Trade-offs

- [随机布局可能偶尔不均匀] → 使用 azimuth 步长基础 + 随机扰动（stratified sampling）可选，但简单 uniform random 在 20 条时统计上已足够均匀，保持简单。
- [过冲量 4% 在大尺寸太阳下可能肉眼不明显] → 接受；目标就是"一点点"，勿过度调参。
- [修改 runSunExpansionAnimation 可能影响回程动画时序] → 回程动画在 `runSunReturnAnimation` 中独立实现，不耦合，无影响。
- [spring 总时长 0.56s 超出 sunDetailTransitionDuration = 0.5s] → completion block 在 0.5s 后触发，将 `isSunTransitionActive` 置 false（解锁 UI），此时 sun 仍在 0.06s 的弹回段。`pauseSunSpinAnimations()` 和 `scheduleEntrySpinAnimation()` 仅操作旋转动画，不干扰位置/scale SCNAction，弹回视觉不受影响。0.06s 窗口内用户重复触发的概率极低，接受此 trade-off。
- [仅靠目视验收可能漏检回归] → 增加最小 smoke 用例，自动校验射线数量、长度映射区间、spring 分段时长和最终收敛位置；保留目视验收用于质感判断。

## Migration Plan

- 仅修改 `WeatherSceneManager.swift` 中 4 个私有方法，无迁移步骤。
- 回滚路径：恢复 `makeSunBurstNode()`、`makeSunBurstRayNode()`、`runSunBurstAnimation()`、`runSunExpansionAnimation()` 四个方法到原始实现。
- 实施后新增或扩展 `SmokeTests/` 下轻量用例，作为参数回归门禁（不替代视觉验收）。
- 无数据迁移、无接口变更、无需 feature flag。

## Open Questions

- 无。所有设计决策已在 Explore 阶段与用户确认。
