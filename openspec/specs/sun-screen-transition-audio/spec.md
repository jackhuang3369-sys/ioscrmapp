## Purpose

定义太阳详情屏切换过渡时的专属进入/退出音效行为，以及 `WeatherAudioPlayer` 对 `.wav` 格式的支持，确保切屏体验与现有其他音效调用互不干扰。

---

## Requirements

### Requirement: 第一屏切换到第二屏时播放专属进入音效
当用户在第一屏点击太阳触发切屏过渡时，系统 SHALL 播放 `sun-detail-enter.wav` 音效，音量为 `0.52`。

#### Scenario: 点击太阳进入第二屏
- **WHEN** 用户在 `WeatherMainView` 第一屏点击太阳，`isSunDetailPresented` 为 false
- **THEN** 系统调用 `WeatherAudioPlayer.shared.playSunDetailEnter()`，播放 `sun-detail-enter.wav`，音量 `0.52`

#### Scenario: 对齐后再进入第二屏
- **WHEN** 太阳不在正面朝向，系统先执行 `alignDisplayGroupToFrontForDetail` 对齐动画，完成后调用 `beginSunDetailPresentation()`
- **THEN** 对齐完成后同样调用 `playSunDetailEnter()`，与直接进入路径行为一致

### Requirement: 第二屏切换回第一屏时播放专属退出音效
当用户在第二屏点击空白处触发退出时，系统 SHALL 播放 `sun-detail-exit.wav` 音效，音量为 `0.48`。

#### Scenario: 点击空白处退出第二屏
- **WHEN** 用户在 `WeatherSunDetailOverlay` 点击空白处，`isSunDetailPresented` 为 true 且 `isSunTransitionActive` 为 false
- **THEN** 系统调用 `WeatherAudioPlayer.shared.playSunDetailExit()`，播放 `sun-detail-exit.wav`，音量 `0.48`

### Requirement: WeatherAudioPlayer 支持 .wav 格式音效文件
`WeatherAudioPlayer` 的音效文件查找 SHALL 支持 `.wav` 格式，查找顺序为 `m4a → mp3 → wav`。

#### Scenario: 查找 .wav 音效文件
- **WHEN** 调用 `audioURL(name:)` 且对应的 `.m4a` 和 `.mp3` 文件不存在
- **THEN** 系统在 `WeatherData/Audio/` 目录下查找同名 `.wav` 文件并返回其 URL

#### Scenario: 优先使用 .m4a 文件
- **WHEN** 同名的 `.m4a` 文件存在
- **THEN** 系统返回 `.m4a` 文件的 URL，不查找 `.wav`

### Requirement: 不影响其他现有音效调用
`onAppear` 中的 `playDetailedEnter()` 以及第二屏内太阳点击的 `playSunTapBurst()` 的行为 SHALL 保持不变。

#### Scenario: onAppear 时音效不变
- **WHEN** `WeatherMainView` 的 `onAppear` 触发
- **THEN** 系统调用 `playDetailedEnter()`，播放 `menu-open-1.m4a`，与切屏音效无关

#### Scenario: 第二屏内点击太阳音效不变
- **WHEN** 用户在第二屏点击太阳（`isSunDetailPresented` 为 true）
- **THEN** 系统调用 `playSunTapBurst()`，与切屏音效无关
