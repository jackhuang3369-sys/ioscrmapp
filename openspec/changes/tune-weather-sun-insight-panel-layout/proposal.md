## Why

当前天气太阳详情页中，信息框（从 UV 栏到 Day/Week 切换）的整体宽度与垂直位置和设计参考图存在明显偏差，导致视觉重心偏高、内容区过窄。该问题已经在 iPhone 15/16 尺寸下稳定复现，需要通过一次小范围布局调整恢复设计一致性。

## What Changes

- 调整 WeatherSunInsightPanel 在太阳详情页中的整体宽度为整屏约 2/3（iPhone 15/16 竖屏下目标宽度比例 0.67，允许 ±0.03），使信息框版式与预期一致。
- 在不改动交互逻辑的前提下，微调信息框在页面中的稳态垂直落位：在现有过渡动画参数不变的前提下，引入 -8pt 的稳态 Y 方向修正（允许 ±2pt 调整窗口），并以“无裁剪/无遮挡、位于目标垂直带”作为验收标准。
- 明确本次变更不涉及信息框内部组件重构（曲线、滑块、Day/Week 控件样式与交互行为保持不变）。

## Capabilities

### New Capabilities
- `weather-sun-insight-panel-layout`: 定义太阳详情信息框在 iPhone 15/16 下的目标宽度与垂直位置约束，确保版式与参考图一致。

### Modified Capabilities
- None

## Impact

- Affected code:
  - `ioscrmapp/Modules/Weather/Views/WeatherMainView.swift` 中 `WeatherSunInsightPanel` 的外层布局参数。
- APIs: 无。
- Dependencies: 无新增依赖。
- Systems: 仅影响 Weather 模块的太阳详情 UI 布局，不影响数据层与交互状态机。