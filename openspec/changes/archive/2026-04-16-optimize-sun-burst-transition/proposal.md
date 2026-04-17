## Why

第一屏切换到第二屏时触发的 SunBurst 射线动效存在三个问题：

1. **音视频失同步**：`sun-detail-enter.wav` 的振幅峰值出现在 t=100ms，但 `runSunBurstAnimation()` 被安排在过渡完成回调（t≈520ms）才触发，视觉爆发滞后音频约 420ms，感知完全脱节。
2. **Z 轴层次错误**：射线以太阳球心为原点向全球面扩散，前方射线遮挡了太阳表面，破坏了「日冕感」——视觉上应是太阳在前、射线从后方透出。
3. **颜色与密度缺乏层次**：前方（靠近相机）与后方（远离相机）的射线颜色对比不明显，且前后射线数量均等，未能强化深度感。

## What Changes

- **音频同步**：将 `runSunBurstAnimation()` 从 transition 完成回调中分离，改为在 `startSunDetailTransition` 开始后约 80ms 触发，使视觉爆发帧（80ms + 20ms burstDelay = 100ms）与音频峰值（t=100ms）对齐。
- **Z 轴偏移**：将 `sunBurstNode` 的 Z 坐标偏移到太阳后方（约 `-sunRadius × 0.5`），使爆发中心位于太阳球体内部偏后，前方射线从太阳边缘透出，形成日冕感。
- **颜色增强**：后方射线（z≈-1）颜色从中灰（white≈0.55）调整为近白（white≈0.85），前方射线（z≈+1）保持近黑（white≈0.02），加大前后对比。
- **分布偏置**：将均匀球面采样改为 7:3 前偏分布——约 70% 射线分布在前半球（黑色），约 30% 分布在后半球（浅灰），与 Z 轴颜色策略一致，强化纵深层次。

## Capabilities

### New Capabilities
- `weather-sun-burst-transition`：SunBurst 射线动效的时序、Z 轴位置、颜色映射及空间分布的调优规格。

### Modified Capabilities
- 无。

## Impact

- 受影响文件：`ioscrmapp/Modules/Weather/SceneKit/WeatherSunBurstCore.swift`（颜色常量、新增 burstZOffset 常量）
- 受影响文件：`ioscrmapp/Modules/Weather/SceneKit/WeatherSceneManager.swift`（burst 触发时序、burstNode 位置、射线分布逻辑）
- 受影响文件：`SmokeTests/WeatherSunBurstTransitionSmokeTests.swift`（颜色常量测试值同步更新）
- 无外部 API 变更，无新依赖。
