## 1. 重构 makeSingleSunDetailTitleNode 支持逐字符处理

- [ ] 1.1 将方法从整体字符串处理改为逐字符循环处理
  **保留**：方法签名 `makeSingleSunDetailTitleNode(text: String) -> SCNNode` 不变
- [ ] 1.2 为每个字符调用 `makeSunDetailTitleLetterNode` 创建多层立体节点
- [ ] 1.3 实现 cursor X 位置累进计算：`cursorX += width + letterSpacing`，间距 = 0.18
- [ ] 1.4 设置容器 pivot 基于 boundingBox 居中
- [ ] 1.5 设置容器整体缩放为 SCNVector3(0.09, 0.09, 0.09)

## 2. 新增 makeSunDetailTitleLetterNode 创建多层叠加节点

- [ ] 2.1 创建新方法签名：`makeSunDetailTitleLetterNode(character: String, font: UIFont) -> SCNNode`
- [ ] 2.2 调用 `makeSunDetailTitleLetterGeometry` 创建文字几何体
- [ ] 2.3 实现9层偏移轮廓节点数组：
  ```
  outlineOffsets: [SCNVector3] = [
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
  ```
- [ ] 2.4 每个轮廓节点设置 scale = SCNVector3(1.18, 1.18, 1)
- [ ] 2.5 添加前景节点在最前面（position = (centerX, centerY, 0)）

## 3. 新增 makeSunDetailTitleLetterGeometry 创建带描边的几何体

- [ ] 3.1 创建新方法签名：`makeSunDetailTitleLetterGeometry(character: String, font: UIFont) -> SCNText`
- [ ] 3.2 使用 NSAttributedString 添加描边属性：
  ```
  attributes: [NSAttributedString.Key: Any] = [
      .font: font,
      .strokeWidth: NSNumber(value: -3),
      .strokeColor: UIColor(red: 0.16, green: 0.16, blue: 0.17, alpha: 1)
  ]
  ```
- [ ] 3.3 设置 extrusionDepth = 1.9
- [ ] 3.4 设置 flatness = 0.06
- [ ] 3.5 设置 chamferRadius = 0.10
- [ ] 3.6 设置 truncationMode、alignmentMode、isWrapped 属性
- [ ] 3.7 调用 `makeSunDetailTitleMaterials` 设置材质

## 4. 新增 makeSunDetailTitleMaterials 统一材质配置

- [ ] 4.1 创建新方法签名：`makeSunDetailTitleMaterials() -> [SCNMaterial]`
- [ ] 4.2 配置 Front 材质：
  ```
  lightingModel = .physicallyBased
  diffuse = UIColor(red: 0.16, green: 0.16, blue: 0.17, alpha: 1)
  metalness = 0.52
  roughness = 0.24
  specular = UIColor(white: 0.98, alpha: 1)
  isDoubleSided = false
  ```
- [ ] 4.3 配置 Side 材质：
  ```
  lightingModel = .physicallyBased
  diffuse = UIColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1)
  metalness = 0.84
  roughness = 0.20
  isDoubleSided = false
  ```
- [ ] 4.4 返回材质数组 `[front, side, side, side, front]`

## 5. 验证

- [ ] 5.1 在模拟器上进入第二屏，目视确认 "Sun" 标题呈现立体浮雕效果
- [ ] 5.2 目视确认标题有明显的阴影轮廓层，而非单层平面文字
- [ ] 5.3 目视确认标题与第一屏温度数字视觉风格一致
- [ ] 5.4 确认切换其他维度（Cloud、Air、Moon）标题同样呈现立体效果
- [ ] 5.5 `xcodebuild` 编译通过，无警告新增