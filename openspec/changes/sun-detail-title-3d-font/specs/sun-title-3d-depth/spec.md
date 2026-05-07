## ADDED Requirements

### Requirement: Per-character title generation
Sun详情页标题 SHALL 采用逐字符处理方式生成，每个字符独立构建多层叠加的立体效果。

#### Scenario: Character separation
- **WHEN** 调用 `makeSingleSunDetailTitleNode(text: "Sun")`
- **THEN** 生成的容器节点包含3个子节点，分别对应 "S"、"u"、"n" 三个字符

#### Scenario: Cursor progression
- **WHEN** 按顺序处理每个字符
- **THEN** 每个字符节点的 X 位置基于前一个字符宽度 + 间距(0.18)累进计算

### Requirement: Multi-layer depth overlay
每个字符 SHALL 由9层偏移叠加的轮廓节点构成立体阴影效果，轮廓节点均匀分布在中心及四周8个方向。

#### Scenario: Outline count
- **WHEN** 检查单个字符节点的子节点数量
- **THEN** 包含恰好9个轮廓节点 + 1个前景节点 = 10个子节点

#### Scenario: Outline positions
- **WHEN** 检查9个轮廓节点的位置偏移
- **THEN** 偏移覆盖中心底层(0,0,-0.06)、左(-0.38,0,-0.08)、右(0.38,0,-0.08)、上(0,0.32,-0.08)、下(0,-0.32,-0.08)及四个角方向

#### Scenario: Outline scale
- **WHEN** 检查每个轮廓节点的缩放
- **THEN** XY方向缩放为1.18（放大18%），Z方向缩放为1

### Requirement: Stroke attribute on geometry
文字几何体 SHALL 使用 NSAttributedString 添加描边效果，描边宽度为3像素，绘制在文字轮廓外侧。

#### Scenario: Stroke width
- **WHEN** 创建 `makeSunDetailTitleLetterGeometry`
- **THEN** NSAttributedString 包含 `.strokeWidth: NSNumber(value: -3)` 属性

#### Scenario: Stroke color
- **WHEN** 创建文字几何体
- **THEN** 描边颜色为 UIColor(red: 0.16, green: 0.16, blue: 0.17, alpha: 1)

### Requirement: Extrusion depth and chamfer
文字几何体 SHALL 设置 extrusionDepth = 1.9，chamferRadius = 0.10，flatness = 0.06。

#### Scenario: Depth parameter
- **WHEN** 创建 SCNText 几何体
- **THEN** extrusionDepth 恰好为 1.9

#### Scenario: Chamfer radius
- **WHEN** 创建 SCNText 几何体
- **THEN** chamferRadius 恰好为 0.10

### Requirement: Material separation
文字几何体 SHALL 使用前后材质分离配置，Front材质呈现光滑金属质感，Side材质呈现深色立体边缘。

#### Scenario: Front material
- **WHEN** 检查 Front 材质属性
- **THEN** diffuse = (0.16, 0.16, 0.17), metalness = 0.52, roughness = 0.24, specular = 0.98

#### Scenario: Side material
- **WHEN** 检查 Side 材质属性
- **THEN** diffuse = (0.08, 0.08, 0.09), metalness = 0.84, roughness = 0.20

### Requirement: Container pivot and scale
生成的容器节点 SHALL 设置中心 pivot，整体缩放为 0.09。

#### Scenario: Pivot centered
- **WHEN** 容器节点包含所有字符后
- **THEN** pivot 基于 boundingBox 计算，使容器以自身中心为原点

#### Scenario: Uniform scale
- **WHEN** 设置容器缩放
- **THEN** XYZ 方向统一缩放为 0.09

### Requirement: Font specification
文字 SHALL 使用系统字体，字号 10.8，weight 为 black。

#### Scenario: Font parameters
- **WHEN** 创建字体实例
- **THEN** font = UIFont.systemFont(ofSize: 10.8, weight: .black)