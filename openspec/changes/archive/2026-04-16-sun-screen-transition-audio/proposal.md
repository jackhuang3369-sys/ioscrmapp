## Why

Weather 模块的第一屏与第二屏切换目前分别使用通用音效 `menu-open-1`（进入）和 `shape-tap-1`（退出），这两个音效与切屏动作的视觉感受不匹配。现有候选音效 `candidate_001.wav` / `candidate_002.wav` 经过专项设计，更契合太阳切屏的质感，需要接入并替换。

## What Changes

- 将音效文件 `candidate_001.wav` 重命名为 `sun-detail-enter.wav`，用于第一屏 → 第二屏的切屏动作
- 将音效文件 `candidate_002.wav` 重命名为 `sun-detail-exit.wav`，用于第二屏 → 第一屏的切屏动作
- 在 `WeatherAudioPlayer` 中新增两个语义化方法 `playSunDetailEnter()` 和 `playSunDetailExit()`，音量分别设为 `0.52` 和 `0.48`（较现有同类音效提升约 30%）
- 扩展 `audioURL` 方法，支持 `.wav` 格式的音效文件查找
- 在 `WeatherMainView` 的 `beginSunDetailPresentation()` 中，将 `playDetailedEnter()` 替换为 `playSunDetailEnter()`
- 在 `WeatherMainView` 的 `exitSunDetail()` 中，将 `playShapeTap()` 替换为 `playSunDetailExit()`
- 保持 `onAppear` 中的 `playDetailedEnter()` 不变（首次进入天气模块的音效，与切屏无关）

## Capabilities

### New Capabilities

- `sun-screen-transition-audio`：Weather 模块第一屏与第二屏之间切换时的专属音效能力，包含进入和退出两个方向，各自使用独立的音效文件和播放方法

### Modified Capabilities

（无）

## Impact

- **文件**：`ioscrmapp/Modules/Weather/WeatherData/Audio/`（重命名两个 wav 文件）
- **代码**：`WeatherAudioPlayer.swift`（新增方法、扩展格式支持）
- **代码**：`WeatherMainView.swift`（替换两处调用点）
- **无 API 变更，无破坏性变更**
