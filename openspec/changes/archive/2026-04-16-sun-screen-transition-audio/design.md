## Context

Weather 模块分为两屏：第一屏（主视图）展示天气概览和 SceneKit 太阳动画；第二屏（Sun Detail Overlay）展示详细的太阳信息面板。两屏之间的切换目前各自复用通用音效：进入时调用 `playDetailedEnter()`（`menu-open-1.m4a`），退出时调用 `playShapeTap()`（`shape-tap-1.m4a`）。

现有专项设计的候选音效文件 `candidate_001.wav` / `candidate_002.wav` 已存在于 `WeatherData/Audio/` 目录，尚未接入。`WeatherAudioPlayer` 当前只扫描 `m4a` 和 `mp3` 格式，不支持 `.wav`。

## Goals / Non-Goals

**Goals:**
- 为第一屏 → 第二屏切换接入 `sun-detail-enter.wav`
- 为第二屏 → 第一屏切换接入 `sun-detail-exit.wav`
- 使 `WeatherAudioPlayer` 支持 `.wav` 格式资源查找
- 新增语义化播放方法，不修改现有通用方法的签名或行为

**Non-Goals:**
- 不修改 `onAppear` 中首次进入天气模块的 `playDetailedEnter()` 调用
- 不修改 `playSunTapBurst()` 及第二屏内太阳点击的音效逻辑
- 不对音效文件进行格式转换

## Decisions

### 新增方法而非修改现有方法

`playDetailedEnter()` 在 `onAppear`（首次进入）和 `beginSunDetailPresentation()`（切屏）两处被调用，职责混用。`playShapeTap()` 名字通用，未来可能复用于其他交互。

**决定**：新增 `playSunDetailEnter()` 和 `playSunDetailExit()`，职责单一，调用点替换只涉及 `WeatherMainView` 中的两处切屏位置。

备选方案：直接修改 `playDetailedEnter()` 的音效文件名——会影响 `onAppear` 的用途，被排除。

### 扩展 `.wav` 支持而非转换文件格式

候选音效以 `.wav` 交付，`AVAudioPlayer` 原生支持 `.wav`，直接接入成本最低。

**决定**：在 `audioURL()` 的格式搜索列表中追加 `"wav"`，搜索顺序为 `["m4a", "mp3", "wav"]`，保持现有文件优先级不变。

### 音量值

进入音效：`0.52`，退出音效：`0.48`，较同类切屏音效提升约 30%，与交互动作的视觉权重相匹配。

## Risks / Trade-offs

- **[风险] `.wav` 文件体积通常大于 `.m4a`** → 候选文件为短时音效，实际包体积影响可忽略
- **[风险] `onAppear` 仍使用旧音效** → 这是预期行为，首次进入天气模块与切屏是不同的交互场景，有意保留区分

## Migration Plan

1. 重命名音频文件（`candidate_001.wav` → `sun-detail-enter.wav`，`candidate_002.wav` → `sun-detail-exit.wav`）
2. 修改 `WeatherAudioPlayer.swift`：扩展格式支持、新增两个播放方法
3. 修改 `WeatherMainView.swift`：替换两处调用点
4. 无需数据迁移，无需回滚策略（音效降级最多回退到旧文件名）
