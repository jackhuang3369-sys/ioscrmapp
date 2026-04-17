# sun-transition-haptic

## Purpose

定义太阳过渡动画触觉反馈的行为规范，包括触觉播放时机、衰减曲线、引擎预热、回程静默及重入保护。

## Requirements

### Requirement: 点击太阳触发连续衰减触觉反馈
当用户在第一屏点击太阳触发进入第二屏的过渡动画时，系统 SHALL 播放一段持续 500ms 的连续触觉震动，intensity 从 0.8 线性衰减至 0.1，sharpness 恒为 0.5，与过渡动画同步开始、同步结束。

#### Scenario: 点击太阳时触觉与音效同帧触发
- **WHEN** 用户点击太阳且 `isSunDetailPresented` 为 false
- **THEN** 触觉震动 SHALL 在与 `playSunDetailEnter()` 相同的调用帧内启动

#### Scenario: 震动强度线性衰减
- **WHEN** 触觉震动播放至任意时刻 `t`（单位：秒，0 ≤ t ≤ 0.5s）
- **THEN** 该时刻的 intensity SHALL 满足：`intensity(t) = 0.8 - 0.7 * (t / 0.5)`，误差不超过 0.001

#### Scenario: 震动在太阳落位时以余震结束
- **WHEN** 触觉震动播放至 `t = 500ms`
- **THEN** intensity SHALL 为 0.1（非 0.0），不骤停

#### Scenario: 不支持 CoreHaptics 的设备静默跳过
- **WHEN** `CHHapticEngine.capabilitiesForHardware().supportsHaptics` 返回 false
- **THEN** 系统 SHALL 跳过触觉播放，不抛出错误，不影响动画与音效

### Requirement: 引擎预热避免首帧延迟
系统 SHALL 在触发过渡动画前预热 `CHHapticEngine`，确保 `playSunTransitionFade()` 触发时引擎已就绪，冷启动延迟不可见。

#### Scenario: prepareSunTransition 在动画触发前调用
- **WHEN** `enterSunDetail()` 开始执行
- **THEN** `WeatherHapticPlayer.shared.prepareSunTransition()` SHALL 在 `startSunDetailTransition()` 被调用之前被调用

### Requirement: 回程动画不触发触觉反馈
系统 SHALL NOT 在退出第二屏（回程动画）时触发任何震动。

#### Scenario: 退出第二屏无触觉
- **WHEN** 用户触发 `exitSunDetail()`
- **THEN** `WeatherHapticPlayer` SHALL NOT 播放任何触觉事件

### Requirement: 重复快速触发不叠加震动
若过渡动画意外重入（`isSunTransitionActive` guard 失效的极端情况），系统 SHALL 在启动新震动前停止上一次未完成的震动，不允许两个 pattern player 同时运行。

#### Scenario: 重入时旧震动被取消
- **WHEN** `playSunTransitionFade()` 被连续调用两次
- **THEN** 第一次震动 SHALL 在第二次开始前被停止
