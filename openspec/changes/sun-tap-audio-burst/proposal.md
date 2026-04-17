# Sun Tap Audio Burst — 太阳点击随机音效播放

## Why

点击太阳进入第二屏时，现有的视觉爆发动画（20条射线、颜色深度、spring过冲）缺乏**声音反馈**。多感官刺激（视觉+声音）能增强点击的即时感与满足度；随机音效变化（sfx_001-007共7个）避免重复疲劳，创造惊喜感。

同时，快速跳跃点击场景中需要保证**多线程安全** — 之前有过快速滑动导致线程崩溃的案例，此设计需谨慎应对并发场景。

## What Changes

- 在 `WeatherAudioPlayer` 中增加串行队列 `audioQueue`，所有 pool 操作都通过此队列执行，保证线程安全。
- 在 `WeatherAudioPlayer` 中补充音频资源解析：在既有 m4a 逻辑外，增加 mp3 fallback（`sfx_001` 到 `sfx_007` 当前为 mp3）。
- 新增 `playSunTapBurst()` 方法，每次调用时从 sfx_001-007 中**随机选一个**播放，且支持**连续点击时的音量递减**：
  - 首次 1-2 次点击：`volume = 0.36`（明亮）
  - 第 3-4 次点击：`volume = 0.28`（稍弱）
  - 第 5 次以上：`volume = 0.20`（更弱，防止听觉疲劳）
  - 约 500ms 无新播放请求时，计数器 reset 为 0。
- 在 `WeatherSceneView.Coordinator.handleTap()` 中检测到太阳点击时，立即触发 `WeatherAudioPlayer.shared.playSunTapBurst()`，实现与视觉爆发同步的声效。
- Sun Tap 声效采用**全局单实例通道**（而非按文件名分池），保证任意时刻最多 1 条 sun-tap 音效在播，避免快速点击时多音轨叠加。

## Capabilities

### New Capabilities

- `sun-tap-audio`: 太阳点击音效系统——从 7 个音效文件随机播放，支持连续点击的音量递减，多线程安全的单实例播放通道管理。

### Modified Capabilities

None.

## Impact

- 修改 `WeatherAudioPlayer.swift`，增加串行队列、计数器、音量计算逻辑。
- 修改 `WeatherAudioPlayer.swift`，增加 mp3 fallback 资源查找。
- 修改 `WeatherSceneView.swift` 的 `Coordinator.handleTap()`，触发音效播放。
- 不修改场景节点、动画参数、或其他音频系统。
- 新增 smoke 用例验证：mp3 fallback、生效随机范围、音量映射精度、单实例播放通道语义。

## Risks / Trade-offs

- [串行队列延迟] → 使用 `.default` QoS（不是 background）保证响应时间；500ms 的 reset 时间充分，不会导致用户感知延迟。
- [随机选中的文件恰好重复] → 允许重复，符合“每次随机播放一个”的需求；若后续希望降低重复率，可改为无放回窗口采样。
- [快速点击导致声音被频繁截断] → 单实例通道在高频点击下会优先播放最新请求，旧请求可能被中止；这是为“低延迟反馈与不重叠”做的有意取舍。
- [某些 sfx 文件格式或质量问题] → 已确认 sfx_001-007 ×7 均为 mp3，大小 15-28KB，应无格式问题；播放失败 silent fail（不影响 UI）。

## Migration Plan

- 无迁移步骤，功能独立。
- 回滚路径：移除 `playSunTapBurst()` 方法及其调用位置。
- 无需 feature flag，新功能始终启用。
