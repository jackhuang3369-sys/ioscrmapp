---
change-id: tune-weather-sun-transition-smoothness
status: proposed
owner: TBD
---

## 问题
天气第一屏点击太阳进入第二屏的转场偏慢、分段明显：存在预对齐 + 主转场串联，且大量使用 `easeInEaseOut` 导致“不够脆”；SwiftUI 面板与 SceneKit 主转场时间线错位，标题出场偏晚。

## 目标
让“点太阳进第二屏 / 返回第一屏”的转场更快、更同步、更流畅，整体手感更接近 No Boring Weather（快起步、收得住、无拖尾）。

## 范围
- 缩短关键时长（主转场、预对齐、返回）
- 调整缓动曲线（弱化 `easeInEaseOut`）
- 对齐 SwiftUI overlay 与 SceneKit 转场时间线
- 提前标题/关键信息的出场节奏

## 非目标
- 不改 UI 结构与视觉稿风格
- 不迁移渲染框架（仍使用 SceneKit）
- 不引入全新手势/交互模型

## 风险
- 参数调整可能影响不同屏幕尺寸设备的观感；需要小/大屏回归
- 过度提速可能造成“突兀”；需保留可控的收尾与回弹余量

