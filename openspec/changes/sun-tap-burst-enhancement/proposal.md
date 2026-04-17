## Why

点击太阳进入第二屏时，现有射线爆发动画视觉层次单薄：12条固定方向射线、颜色二值区分、缺乏空间深度感。太阳移动至中心的动画虽有缓动但没有弹性感，缺少生命感。

## What Changes

- 将 `makeSunBurstNode()` 中的 12条 hardcoded 射线替换为 20条随机分布射线，具备真实的深度分层视觉效果。
- 射线颜色和透明度改为基于 Z 轴深度连续映射，靠前(z>0)深灰高不透明，靠后(z<0)浅灰低不透明。
- 射线起始位置在太阳边缘 ±5% 半径范围内随机抖动，视觉上打破整齐圆环感。
- 射线长度分三档随机分布（短20%、中60%、长20%），向外飞出距离与长度比例联动。
- 射线播放顺序按 Z 深度分层错帧，强化前后层次感。
- 太阳入场动画改为带微量过冲的 spring 效果：先轻微越过中心终点约4%，再弹回归位。
- 增加最小化 smoke 验证，覆盖射线数量、射线长度映射区间、spring 两段时序与终点收敛。

## Capabilities

### New Capabilities
- `sun-burst-rays`: 太阳点击爆发射线系统——随机分布、深度分层颜色、边缘抖动起始位置、多档长度分布。
- `sun-tap-spring`: 太阳点击后移动至中心屏的 spring 入场动画——非常轻微的过冲与弹回效果。

### Modified Capabilities

None.

## Impact

- 只影响 `WeatherSceneManager.swift`，具体涉及 `makeSunBurstNode()`、`makeSunBurstRayNode()`、`runSunBurstAnimation()`、`runSunExpansionAnimation()` 四个私有方法。
- 新增或扩展 `SmokeTests/` 下的轻量 smoke 用例文件，用于回归验证关键参数与时序。
- 不修改场景层级、节点命名或公共接口。
- 不影响回程动画（return transition）、自动旋转、粒子、音频等其他系统。
