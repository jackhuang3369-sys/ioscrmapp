## Context

`WeatherSceneManager` 中的 `makeSingleSunDetailTitleNode` 当前使用单层 `SCNText` 生成整个标题字符串，设置 `extrusionDepth: 1.8` 提供基础深度，但缺乏多层叠加的阴影轮廓效果。第一屏温度数字通过 OBJ 模型文件加载，保留了原始设计中的立体浮雕效果。第二屏标题与第一屏视觉风格不一致。

`3d-UI-ray` 分支已实现完整的多层立体方案，包含9层偏移叠加轮廓和描边效果。本次改动将移植该实现到当前分支。

改动范围严格限于 `WeatherSceneManager.swift` 的标题生成方法，不触碰公共接口、场景层级或其他动画系统。

## Goals / Non-Goals

**Goals:**
- 将标题生成改为逐字符处理，支持独立的多层叠加
- 为每个字符创建9层偏移轮廓节点，配合18%放大形成立体阴影
- 添加 NSAttributedString 描边效果增强边缘锐度
- 统一前后材质配置，保持与温度数字视觉一致性
- 复用 `3d-UI-ray` 分支已验证的实现方案

**Non-Goals:**
- 不修改场景层级、节点命名、公共接口
- 不引入新的 SceneKit 节点类型或外部依赖
- 不修改温度数字的渲染逻辑
- 不影响回程动画或其他动画系统

## Decisions

### 1. 逐字符处理 vs 整体字符串

选择逐字符处理方案。理由：每个字符需要独立的多层叠加轮廓，整体字符串无法对单个字符进行偏移控制。替代方案（整体字符串后叠加多个偏移副本）会导致字符间重叠混乱，被放弃。

### 2. 9层偏移叠加结构

```
outlineOffsets: [SCNVector3] = [
    SCNVector3(0, 0, -0.06),       // 中心底层
    SCNVector3(-0.38, 0, -0.08),   // 左
    SCNVector3(0.38, 0, -0.08),    // 右
    SCNVector3(0, -0.32, -0.08),   // 下
    SCNVector3(0, 0.32, -0.08),    // 上
    SCNVector3(-0.28, -0.28, -0.08), // 左下
    SCNVector3(0.28, -0.28, -0.08),  // 右下
    SCNVector3(-0.28, 0.28, -0.08),  // 左上
    SCNVector3(0.28, 0.28, -0.08)    // 右上
]
```

每个轮廓节点 scale = (1.18, 1.18, 1)，即XY方向放大18%。中心底层+四周8个方向形成完整的立体阴影框架。

### 3. 描边效果

使用 NSAttributedString 添加描边：
```
attributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .strokeWidth: NSNumber(value: -3),      // 负值=描边在外
    .strokeColor: UIColor(red: 0.16, green: 0.16, blue: 0.17, alpha: 1)
]
```

strokeWidth: -3 表示描边宽度为3像素，负值表示描边绘制在文字轮廓外侧。

### 4. 材质配置

前后材质分离：
- **Front**: diffuse = (0.16, 0.16, 0.17), metalness = 0.52, roughness = 0.24, specular = 0.98
- **Side**: diffuse = (0.08, 0.08, 0.09), metalness = 0.84, roughness = 0.20

Front 材质高金属度低粗糙度，呈现光滑金属质感；Side 材质高金属度更低粗糙度，呈现深色立体边缘。

### 5. 字符间距

字符间距设置为 0.18 单位，配合整体缩放 0.09，最终视觉间距适中。

## Risks / Trade-offs

- [多层叠加增加渲染开销] → 9层叠加每个标题约增加9倍几何体，但标题字符数少（通常3-5字符），总开销可控
- [描边在某些字体下可能不清晰] → 使用系统黑体(.black weight)，描边效果稳定
- [缩放参数 0.09 可能需要微调] → 采用 `3d-UI-ray` 分支已验证参数，无需额外调参
- [与其他维度标题视觉一致性] → 所有维度标题共享同一套方法，自动保持一致

## Migration Plan

- 仅修改 `WeatherSceneManager.swift` 中标题生成相关方法，无迁移步骤
- 回滚路径：恢复 `makeSingleSunDetailTitleNode` 到原始单层实现
- 实施后无需新增 smoke 用例，视觉效果通过目视验收确认
- 无数据迁移、无接口变更、无需 feature flag

## 3d-UI-ray 分支实际实现代码

### `makeSingleSunDetailTitleNode`（逐字符编排）

```swift
private func makeSingleSunDetailTitleNode(text: String) -> SCNNode {
    let font = UIFont.systemFont(ofSize: 10.8, weight: .black)
    let container = SCNNode()
    var cursorX: Float = 0
    let letterSpacing: Float = 0.18

    for character in text {
        let letterNode = makeSunDetailTitleLetterNode(character: String(character), font: font)
        let (minBounds, maxBounds) = letterNode.boundingBox
        let width = maxBounds.x - minBounds.x
        letterNode.position = SCNVector3(cursorX - minBounds.x, -minBounds.y, 0)
        container.addChildNode(letterNode)
        cursorX += width + letterSpacing
    }

    let (minBounds, maxBounds) = container.boundingBox
    let width = maxBounds.x - minBounds.x
    let height = maxBounds.y - minBounds.y
    container.pivot = SCNMatrix4MakeTranslation(
        minBounds.x + width / 2,
        minBounds.y + height / 2,
        0
    )
    container.scale = SCNVector3(0.09, 0.09, 0.09)
    return container
}
```

### `makeSunDetailTitleLetterNode`（9层偏移叠加）

```swift
private func makeSunDetailTitleLetterNode(character: String, font: UIFont) -> SCNNode {
    let textGeometry = makeSunDetailTitleLetterGeometry(character: character, font: font)
    let measureNode = SCNNode(geometry: textGeometry)
    let (minBounds, maxBounds) = measureNode.boundingBox
    let centerX = minBounds.x + (maxBounds.x - minBounds.x) / 2
    let centerY = minBounds.y + (maxBounds.y - minBounds.y) / 2

    let container = SCNNode()

    // Build a visible faux-bold outline with several enlarged underlays.
    let outlineOffsets: [SCNVector3] = [
        SCNVector3(0, 0, -0.06),
        SCNVector3(-0.38, 0, -0.08),
        SCNVector3(0.38, 0, -0.08),
        SCNVector3(0, -0.32, -0.08),
        SCNVector3(0, 0.32, -0.08),
        SCNVector3(-0.28, -0.28, -0.08),
        SCNVector3(0.28, -0.28, -0.08),
        SCNVector3(-0.28, 0.28, -0.08),
        SCNVector3(0.28, 0.28, -0.08)
    ]
    for offset in outlineOffsets {
        let outlineGeometry = textGeometry.copy() as? SCNGeometry
            ?? makeSunDetailTitleLetterGeometry(character: character, font: font)
        let outlineNode = SCNNode(geometry: outlineGeometry)
        outlineNode.pivot = SCNMatrix4MakeTranslation(centerX, centerY, 0)
        outlineNode.position = SCNVector3(centerX + offset.x, centerY + offset.y, offset.z)
        outlineNode.scale = SCNVector3(1.18, 1.18, 1)
        container.addChildNode(outlineNode)
    }

    let foregroundNode = SCNNode(geometry: textGeometry)
    foregroundNode.pivot = SCNMatrix4MakeTranslation(centerX, centerY, 0)
    foregroundNode.position = SCNVector3(centerX, centerY, 0)
    container.addChildNode(foregroundNode)

    return container
}
```

### `makeSunDetailTitleLetterGeometry`（描边+挤压）

```swift
private func makeSunDetailTitleLetterGeometry(character: String, font: UIFont) -> SCNText {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .strokeWidth: NSNumber(value: -3),
        .strokeColor: UIColor(red: 0.16, green: 0.16, blue: 0.17, alpha: 1)
    ]
    let textGeometry = SCNText(
        string: NSAttributedString(string: character, attributes: attributes),
        extrusionDepth: 1.9
    )
    textGeometry.flatness = 0.06
    textGeometry.chamferRadius = 0.10
    textGeometry.truncationMode = CATextLayerTruncationMode.none.rawValue
    textGeometry.alignmentMode = CATextLayerAlignmentMode.left.rawValue
    textGeometry.isWrapped = false
    textGeometry.materials = makeSunDetailTitleMaterials()
    return textGeometry
}
```

### `makeSunDetailTitleMaterials`（前后材质分离）

```swift
private func makeSunDetailTitleMaterials() -> [SCNMaterial] {
    let front = SCNMaterial()
    front.lightingModel = .physicallyBased
    front.diffuse.contents = UIColor(red: 0.16, green: 0.16, blue: 0.17, alpha: 1)
    front.metalness.contents = Float(0.52)
    front.roughness.contents = Float(0.24)
    front.specular.contents = UIColor(white: 0.98, alpha: 1)
    front.isDoubleSided = false

    let side = SCNMaterial()
    side.lightingModel = .physicallyBased
    side.diffuse.contents = UIColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1)
    side.metalness.contents = Float(0.84)
    side.roughness.contents = Float(0.20)
    side.isDoubleSided = false

    return [front, side, side, side, front]
}
```

### 分支实现与 design.md 原描述的差异

| 项目 | design.md 原描述 | 分支实际代码 |
|------|------------------|--------------|
| 字体大小 | 未明确 | `10.8`（vs 当前 `9.2`） |
| extrusionDepth | 未提及 | `1.9`（vs 当前 `1.8`） |
| chamferRadius | 未提及 | `0.10`（轮廓层与正面层相同） |
| 轮廓层几何体复用 | 未提及 | `textGeometry.copy() as? SCNGeometry ?? 重新生成` |
| truncationMode | 未提及 | `.none` |
| alignmentMode | 未提及 | `.left` |
| isWrapped | 未提及 | `false` |
| 轮廓层 pivot | 未提及 | 与正面层相同 `SCNMatrix4MakeTranslation(centerX, centerY, 0)` |

## 当前实现 vs 方案对比

### 当前实现 (`makeSingleSunDetailTitleNode`, WeatherSceneManager.swift:1802)

```
SCNText(整体字符串) → extrusionDepth: 1.8 → 单层几何体
├── Front: metalness 0.26, roughness 0.50, specular 0.70
├── Side:  metalness 0.84, roughness 0.20
├── chamferRadius: 0.10
├── scale: 0.1088
└── 无偏移叠加、无描边
```

- 整体字符串处理，无法对单个字符做偏移控制
- 单层几何体，仅靠 extrusionDepth 提供深度，缺乏多层叠加的阴影轮廓
- 前材质金属度低(0.26)、粗糙度高(0.50)，呈现偏哑光效果
- 与第一屏温度数字的 OBJ 模型立体浮雕风格差距明显

### 方案实现（3d-UI-ray 分支已验证）

```
逐字符 SCNText + 9层偏移叠加 + NSAttributedString描边
├── 中心层 z=-0.06 + 8方向轮廓层 z=-0.08
├── 轮廓层 scale=(1.18, 1.18, 1) → 18%放大
├── Front: metalness 0.52, roughness 0.24, specular 0.98
├── Side:  metalness 0.84, roughness 0.20（不变）
├── strokeWidth: -3, strokeColor: (0.16, 0.16, 0.17)
├── 字符间距 0.18, 整体 scale: 0.09
└── compositingGroup 合成
```

### 关键差异

| 维度 | 当前实现 | 3d-UI-ray 方案 |
|------|----------|-----------------|
| 字符处理 | 整体字符串 | 逐字符 |
| 几何层数 | 1层 | 9层（1中心+8方向） |
| 轮廓效果 | 无 | 8方向偏移+18%放大 |
| 描边 | 无 | strokeWidth: -3, 外描边 |
| Front metalness | 0.26 | 0.52 |
| Front roughness | 0.50 | 0.24 |
| Front specular | 0.70 | 0.98 |
| Side metalness | 0.84 | 0.84（不变） |
| Side roughness | 0.20 | 0.20（不变） |
| chamferRadius | 0.10 | 待定（见注意事项） |
| 视觉风格 | 偏哑光平面 | 金属光泽立体浮雕 |

## 方案评估

### 合理性判断：方案整体合理，可执行

1. **9层偏移叠加** — SceneKit 中创建立体浮雕的标准手法，8方向偏移+中心层形成完整阴影框架，Z轴负偏移让轮廓层退后，逻辑正确
2. **逐字符处理** — 必要的，整体字符串叠加会导致字符间重叠混乱，逐字符可独立控制偏移
3. **NSAttributedString 描边** — strokeWidth: -3 负值=外描边，配合 black weight 字体效果稳定，增强边缘锐度
4. **18%放大** — 轮廓层比正面层略大，形成自然的描边/阴影感，比例合理
5. **性能可控** — 标题通常3-5字符，9层=27-45个节点，SceneKit 可轻松处理

### 需注意的 2 个点

1. **材质变化较大** — Front 的 metalness 0.26→0.52、roughness 0.50→0.24、specular 0.70→0.98，文字从偏哑光变为明显金属光泽。这与第一屏温度数字的 OBJ 模型风格一致（方案目标），但视觉变化较大，需确认是期望效果。

2. **chamferRadius 未提及** — 当前实现有 chamferRadius: 0.10（倒角），方案中没有提到是否保留。9层叠加方案下，轮廓层的倒角可能需要更小或为0，否则放大18%后倒角也会放大导致轮廓层与正面层边缘不齐。建议轮廓层 chamferRadius = 0，正面层保留或微调。

## Open Questions

- 无。设计决策直接采用 `3d-UI-ray` 分支已验证方案。