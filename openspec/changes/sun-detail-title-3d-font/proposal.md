## Why

点击太阳进入第二屏后，"Sun"标题文字的字体缺乏立体效果，与第一屏温度数字的3D立体风格不一致。当前实现使用单层 SCNText，缺少多层叠加的阴影轮廓，视觉上呈现平面感而非立体浮雕感。

## What Changes

- 将 `makeSingleSunDetailTitleNode` 从整体字符串处理改为逐字符处理
- 新增 `makeSunDetailTitleLetterNode` 方法，为每个字符创建多层叠加的立体效果
- 新增 `makeSunDetailTitleLetterGeometry` 方法，生成带描边的文字几何体
- 新增 `makeSunDetailTitleMaterials` 方法，统一配置前后材质
- 实现9层偏移叠加的轮廓节点（前后左右及四个角方向），配合18%放大形成立体阴影
- 添加 NSAttributedString 描边效果（strokeWidth: -3）

## Capabilities

### New Capabilities

- `sun-title-3d-depth`: Sun详情页标题的3D立体浮雕效果——多层叠加轮廓、描边、材质分层。

### Modified Capabilities

None.

## Impact

- 只影响 `WeatherSceneManager.swift`，具体涉及 `makeSingleSunDetailTitleNode` 方法及其新增辅助方法
- 不修改场景层级、节点命名或公共接口
- 不影响其他维度标题（Cloud、Air、Moon等）的渲染逻辑，它们共享同一套方法