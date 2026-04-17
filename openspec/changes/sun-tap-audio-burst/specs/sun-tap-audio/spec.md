## ADDED Requirements

### Requirement: Sun tap must trigger immediate randomized SFX
系统 SHALL 在检测到太阳点击后立即触发一次 sun-tap 音效播放，并从 `sfx_001` 到 `sfx_007` 中随机选择一个文件。

#### Scenario: Tap to SFX trigger
- **WHEN** 用户点击太阳交互区域且命中有效节点
- **THEN** 触发 `playSunTapBurst()`
- **AND** 在同一交互流程中继续执行原有 `onSunTap` 逻辑

#### Scenario: Random selection range
- **WHEN** 任意一次调用 `playSunTapBurst()`
- **THEN** 被请求的音效名称在 `sfx_001` 到 `sfx_007` 范围内

### Requirement: Consecutive taps must apply stepped volume decay
系统 SHALL 在连续点击期间按固定档位衰减音量，并在间隔超过 500ms 后恢复首档音量。

#### Scenario: Early taps are bright
- **WHEN** 在连续点击序列中第 1 次或第 2 次触发播放
- **THEN** 播放音量为 `0.36`

#### Scenario: Middle taps are weaker
- **WHEN** 在连续点击序列中第 3 次或第 4 次触发播放
- **THEN** 播放音量为 `0.28`

#### Scenario: Later taps are soft
- **WHEN** 在连续点击序列中第 5 次及以上触发播放
- **THEN** 播放音量为 `0.20`

#### Scenario: Reset after idle gap
- **WHEN** 两次触发间隔大于 500ms
- **THEN** 连续点击计数重置
- **AND** 下一次播放按首档音量 `0.36`

### Requirement: Sun-tap audio path must be thread-safe and non-crashing
系统 SHALL 通过串行执行的音频控制路径管理 sun-tap 播放状态，避免并发访问导致崩溃。

#### Scenario: Concurrent tap requests
- **WHEN** 短时间内出现多次 tap 请求
- **THEN** sun-tap 状态更新在串行队列内执行
- **AND** 不出现并发写入同一状态容器的行为

### Requirement: Sun-tap playback must use a single global channel
系统 SHALL 使用 sun-tap 全局单实例播放通道，确保任意时刻仅有一条 sun-tap 音效在播。

#### Scenario: Rapid taps do not stack multiple sun-tap tracks
- **WHEN** 用户快速连续点击太阳
- **THEN** 新请求会替换当前 sun-tap 播放
- **AND** 不会出现多个 sun-tap 轨道叠加播放

### Requirement: Audio resource lookup must support existing mp3 assets
系统 SHALL 在既有 m4a 查找逻辑之外支持 mp3 fallback，以兼容当前 sfx 资源格式。

#### Scenario: m4a missing but mp3 exists
- **WHEN** 请求 `sfx_00X` 且 m4a 不存在但 mp3 存在
- **THEN** 返回 mp3 对应 URL 并成功初始化播放器
