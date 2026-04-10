# Not Boring Weather — 演示重建计划（v2）
> 目标：iOS Swift + SceneKit | 2个页面 | 模拟数据 | 嵌入 ioscrmapp 现有项目

---

## 0. 概述

将天气模块作为一个**独立功能**嵌入现有 ioscrmapp 项目。  
通过 HomeView 首页快捷操作区的按钮入口触发，以 `fullScreenCover` 全屏展示。  
无实时数据。无本地化。无独立应用入口。

### 两个页面

| 页面 | 描述 |
|------|------|
| **A · 主天气页** | 全屏 3D SceneKit 场景（风雨雷电昼夜变化）+ 当前温度/天气叠加层 + 底部今日/逐小时简化预报 + 日期切换条 |
| **B · 详情页** | 旋转维度场景：4个维度面板，左右滑动切换；每个面板上 2/3 为 3D 模型可视化，下 1/3 展示核心数据指标 |

### 导航流程

```
HomeView（首页）
  └─ 快捷操作 → [天气] 按钮
       └─► 页面 A（全屏 fullScreenCover）
             ├─ 点击 3D 场景 / 今日卡片
             │    └─► 页面 B（sheet 或 push）
             └─ 下拉 / 关闭按钮 → 返回 HomeView
```

### 与现有项目的集成方式

| 位置 | 改动 |
|------|------|
| `HomeView.swift` | 新增 `isWeatherPresented` state + `.fullScreenCover` + `weather` 快捷操作入口 |
| `HomeItem.Action` | 新增 `.weather` case |
| `handleAction()` | 处理 `.weather` → `isWeatherPresented = true` |
| `quickActions` 数组 | 添加天气快捷条目（使用 SF Symbol 作为图标） |

---

## 1. 资源清单 — 已有 vs 需构建

### 1.1 IPA 中的资源（现已可用）

| 资源 | 文件 | 状态 | 用途 |
|-------|-------|--------|---------|
| **颜色令牌系统** | `cedar-colors.json`、`andy-colors.json`、`opal-colors.json`、`depth-colors.json`、`graphite-colors.json` | ✅ 就绪，普通 JSON | 主题引擎 |
| **主题元数据** | `cedar-theme.json`、`karat-theme.json`、`opal-theme.json`、`presstube-theme.json` | ✅ 就绪 | 主题切换器 |
| **昼夜动画参数** | `cedar-animation.json`、`chroma-animation.json` | ✅ 就绪 | SceneKit 过渡 |
| **Lottie 标题动画** | `cloudburst-title.json` | ✅ 就绪（Lottie v5.7.4） | 页面 A 启动动画 |
| **粒子纹理** | `base1.scnassets/precip-particle-{16,32,64,128}.heic` | ⚠️ 需要 HEIC→PNG | 雨/雪粒子 |
| **Karat 材质纹理** | `karat.scnassets/gold-dim.heic`、`terrazzo-mask.heic` | ⚠️ 需要 HEIC→PNG | 3D 模型材质 |
| **KTX 数字纹理** | `presstube.scnassets/*.ktx`（32个文件） | ⚠️ 需要 KTX→PNG | Presstube 主题数字 |
| **音效** | 14个 × `.caf` 文件 | ⚠️ 需要 CAF→M4A/MP3 | UI 反馈音频 |
| **3D 场景文件** | `*/Models.scn`、`*/Main.scn`、`*/Particles.scn`、`base1.scnassets/Animation-*.scn` | ⚠️ 需要 macOS 导出 | SceneKit 场景 |

### 1.2 我们需要构建的内容

| 资源 | 说明 |
|-------|------|
| 字体 | `FoundersGrotesk` / `NeumaticGothic` 是商业字体 → 使用系统字体替代 |
| 所有 Swift 源代码 | 天气模块逻辑、视图、模型（嵌入 ioscrmapp 的 Modules/Weather/ 目录） |
| SF Symbols 天气图标 | 免费，内置于 iOS |
| 模拟天气数据 | 无实时 API，全部硬编码 |
| 详情页旋转维度面板 | IPA 中不可见，全新设计 |
| HomeView 入口改动 | `HomeItem.Action.weather` + 快捷操作按钮 + `fullScreenCover` |

---

## 2. 工作分工

### 🙋 需要你完成的任务（macOS + Xcode）

这些步骤需要在 Mac 上操作，我无法代替执行。

#### 步骤 U-1 · 导出 `.scn` 文件 → `.dae`（一次性的，macOS）

在 Mac 上创建并运行这个 Swift 命令行脚本：

```swift
// export_scenes.swift — 运行方式：swift export_scenes.swift
import SceneKit
import Foundation

let appPath = "/path/to/simple-weather.app"   // 替换为实际路径
let outputDir = "/path/to/output"              // 输出目录

let scnFiles: [(String, String)] = [
    ("normal.scnassets/Models.scn",    "normal_models"),
    ("normal.scnassets/Main.scn",      "normal_main"),
    ("normal.scnassets/Particles.scn", "normal_particles"),
    ("base1.scnassets/Particles.scn",  "base1_particles"),
    ("base1.scnassets/Animation-cloud-in.scn",  "anim_cloud_in"),
    ("base1.scnassets/Animation-cloud-out.scn", "anim_cloud_out"),
    ("base1.scnassets/Animation-cloud.scn",     "anim_cloud"),
    ("base1.scnassets/Animation-sun-in.scn",    "anim_sun_in"),
    ("base1.scnassets/Animation-sun-out.scn",   "anim_sun_out"),
    ("base1.scnassets/Animation-bolt.scn",      "anim_bolt"),
    ("base1.scnassets/Animation-fog.scn",       "anim_fog"),
]

for (rel, name) in scnFiles {
    let url = URL(fileURLWithPath: "\(appPath)/\(rel)")
    guard let scene = try? SCNScene(url: url, options: nil) else {
        print("❌ 失败：\(rel)"); continue
    }
    let out = URL(fileURLWithPath: "\(outputDir)/\(name).dae")
    scene.write(to: out, options: nil, delegate: nil, progressHandler: nil)
    print("✅ \(name).dae")
}
```

**交付物**：`.dae` 文件夹 → 添加到 `ioscrmapp/Modules/Weather/Resources/Scenes/`。

---

#### 步骤 U-2 · 转换 HEIC 纹理 → PNG（macOS，一条命令）

```bash
cd /path/to/simple-weather.app  # origin/ 目录的实际路径

sips -s format png base1.scnassets/precip-particle-128.heic --out ~/Desktop/textures/precip-128.png
sips -s format png base1.scnassets/precip-particle-64.heic  --out ~/Desktop/textures/precip-64.png
sips -s format png base1.scnassets/precip-particle-32.heic  --out ~/Desktop/textures/precip-32.png
```

**交付物**：3个 PNG → 添加到 `ioscrmapp/Assets.xcassets/`（Weather 分组）。

---

#### 步骤 U-3 · 将资源文件添加到 Xcode 项目

1. 将 `.dae` 文件拖入 Xcode → `Modules/Weather/Resources/Scenes/` 组（勾选"Copy items if needed"）
2. 将 PNG 纹理拖入 `Assets.xcassets`，新建 "WeatherParticles" 分组
3. 复制 `origin/cedar-colors.json`、`origin/cedar-animation.json` → `Modules/Weather/Resources/Themes/`

---

### 👨‍💻 我将编写代码的任务

以下所有 Swift 源文件由我直接写入项目，无需手动粘贴。

---

## 3. 项目结构（嵌入 ioscrmapp）

```
ioscrmapp/
├── Modules/
│   └── Weather/                              ← 天气模块（全部新增）
│       ├── Models/
│       │   ├── WeatherCondition.swift        # 枚举：晴/多云/雨/雪/雷暴/雾 + SF Symbol
│       │   ├── MockWeatherData.swift         # 所有硬编码天气数据
│       │   └── WeatherDetailDimension.swift  # 详情页维度枚举（4个面板）
│       ├── SceneKit/
│       │   ├── WeatherSceneView.swift        # UIViewRepresentable 包装 SCNView
│       │   ├── WeatherSceneManager.swift     # 场景加载/节点/动画控制
│       │   ├── ParticleController.swift      # 雨/雪粒子系统
│       │   └── SceneConstants.swift          # 节点名称常量
│       ├── Views/
│       │   ├── WeatherMainView.swift         # 页面 A 根视图（全屏，含关闭按钮）
│       │   ├── WeatherConditionOverlay.swift # 温度/城市/天气叠加层
│       │   ├── WeatherHourlyStrip.swift      # 底部今日逐小时预报横向滑动条
│       │   ├── WeatherDatePicker.swift       # 日期切换条
│       │   ├── WeatherDetailView.swift       # 页面 B 根视图（旋转维度）
│       │   ├── DimensionPanelView.swift      # 单个维度面板（上 2/3 场景 + 下 1/3 数据）
│       │   └── DimensionDataView.swift       # 各维度数据展示区（温度曲线/风/雨/AQI）
│       └── Resources/
│           ├── Scenes/                       # 导出的 .dae 文件（步骤 U-1 后手动添加）
│           └── Themes/                       # cedar-colors.json, cedar-animation.json
│
└── Modules/Home/Views/
    └── HomeView.swift                        ← 改动：新增 weather 入口
```

### 对 HomeView.swift 的改动摘要

```swift
// 1. 新增 state
@State private var isWeatherPresented = false

// 2. HomeItem.Action 新增 case（在 HomeView.swift 底部的 private enum）
case weather

// 3. quickActions 数组添加天气入口
.init(title: .literal("Weather"), assetName: "cloud.sun.fill", action: .weather)
// （assetName 改用 SF Symbol 名称，或先占位用现有图标）

// 4. handleAction 新增处理
case .weather:
    isWeatherPresented = true

// 5. body 中添加 fullScreenCover
.fullScreenCover(isPresented: $isWeatherPresented) {
    WeatherMainView()
}
```

---

## 4. 页面 A — 主天气视图（详细规格）

### 4.1 视觉规格参考（基于原版截图分析）

#### 太阳（红色圆形）规格

| 属性 | 值 | 说明 |
|------|-----|------|
| **直径** | 屏幕宽度的 **55-60%** | 约 200-220pt（iPhone 15 Pro） |
| **位置** | 城市名下方，数字上方 | 垂直居中偏上 |
| **颜色** | 高饱和度红色 | `#FF2B2B` 或类似 |
| **纹理** | 颗粒/磨砂质感 | 使用噪声纹理叠加 |
| **3D 效果** | 轻微内阴影 + 渐变 | 营造球体感 |

#### 数字 "27" 规格

| 属性 | 值 | 说明 |
|------|-----|------|
| **高度** | 屏幕高度的 **35-40%** | 约 280-320pt |
| **宽度** | 屏幕宽度的 **45-50%** | 约 170-190pt |
| **3D 厚度** | 数字宽度的 **15-20%** | 约 25-35pt |
| **字体** | 自定义粗体几何字体 | 类似 Founders Grotesk Black |
| **3D 效果** | 深度挤压 + 倒角 + 顶部反光 | 红色环境光遮蔽 |

#### 整体比例关系

```
太阳直径 : 数字高度 ≈ 1 : 1.2  （数字略大于太阳）
太阳直径 : 屏幕宽度 ≈ 0.55 : 1
数字宽度 : 屏幕宽度 ≈ 0.45 : 1
```

### 4.2 布局结构

```
┌──────────────────────────────────┐
│  ✕ 关闭按钮（右上角）             │
│                                  │
│  [全屏 SCNView]                   │
│   3D 天气模型居中                 │
│   （云/太阳/雨/雷电/风场景）       │
│   昼夜背景平面 + 雾 + 粒子叠加    │
│          ● ← 红色太阳 (55% 宽)     │
│                                  │
│           27  ← 3D 数字 (40% 高)   │
│                                  │
│  ┌────────────────────────────┐  │
│  │  San Francisco         🌙  │  │ ← 城市 + 昼夜切换
│  │  72°          Partly Cloudy│  │ ← 大温度、天气状况
│  │  H:79°  L:61°              │  │ ← 最高/最低
│  └────────────────────────────┘  │
│                                  │
│  ─── 日期切换条 ───────────────  │
│  [今天] [明天] [周三] [周四]...    │ ← 横向滑动，点击切换
│                                  │
│  ╔══════════════════════════════╗ │
│  ║ 逐小时预报（横向滑动）        ║ │
│  ║ 6AM  7AM  8AM  9AM  10AM... ║ │
│  ║     ☀️   ☀️   ⛅         ║ │
│  ║  65°  68°  70°  71°  69°   ║ │
│  ╚══════════════════════════════╝ │
└──────────────────────────────────┘
         点击场景 → 页面 B（旋转维度）
```

### 4.3 SceneKit 场景组成（页面 A）

| 节点 | 来源 | 备注 |
|------|--------|-------|
| `plane-day` / `plane-night` | `normal.scnassets/Main.scn` | 背景平面，昼夜切换时淡入淡出 |
| 天气 3D 模型 | `normal.scnassets/Models.scn` | 云/太阳/雨/雷电模型，根据天气状况切换 |
| 雾节点 | SceneKit `SCNFog` | 颜色由 `cedar-animation.json → fogColor` 驱动 |
| 雨/雪粒子 | `base1.scnassets/Particles.scn` | 天气状况为雨/雪/雷暴时显示 |
| 动画触发器 | `base1.scnassets/Animation-*.dae` | 天气状况变化 / 昼夜切换时播放 |

### 模拟数据

```swift
struct HourlyForecast {
    let hour: String      // "6 AM"
    let condition: WeatherCondition
    let temperature: Int  // °F
}

let hourlyForecast: [HourlyForecast] = [
    .init(hour: "Now",  condition: .partlyCloudy, temperature: 72),
    .init(hour: "7AM",  condition: .clear,        temperature: 68),
    .init(hour: "8AM",  condition: .clear,        temperature: 70),
    .init(hour: "9AM",  condition: .partlyCloudy, temperature: 71),
    .init(hour: "10AM", condition: .rain,         temperature: 69),
    .init(hour: "11AM", condition: .rain,         temperature: 66),
    .init(hour: "12PM", condition: .thunderstorm, temperature: 64),
]
```

---

## 5. 页面 B — 详情天气视图（旋转维度，新设计）

### 核心交互概念

用户左右滑动在 **4个维度面板** 之间切换，每个面板布局为：
- **上 2/3**：与该维度匹配的 3D SceneKit 场景（各不相同）
- **下 1/3**：该维度的核心数据指标

```
┌──────────────────────────────────┐
│  ← 返回                          │
│  ╔══════════════════════════════╗ │
│  ║         [上 2/3]             ║ │
│  ║    维度专属 3D SceneKit 场景  ║ │
│  ║    （粒子/光影/几何体变化）    ║ │
│  ║                              ║ │
│  ╠══════════════════════════════╣ │
│  ║         [下 1/3]             ║ │
│  ║    核心数据指标展示           ║ │
│  ║    （简洁、大字、视觉优先）   ║ │
│  ╚══════════════════════════════╝ │
│                                  │
│  ● ○ ○ ○   ← 维度指示点         │
│  ← 左右滑动切换维度 →            │
└──────────────────────────────────┘
```

### 4个维度面板设计

| # | 维度 | 3D 场景内容（上 2/3） | 数据指标（下 1/3） |
|---|------|---------------------|------------------|
| 1 | 🌡 **温度** | 太阳/云 3D 模型 + 动态光照，昼夜背景 | 当前温度（大字）、体感温度、今日高/低 |
| 2 | 💨 **风** | 粒子流线模拟风向运动 | 风速（大字）、风向方位、阵风速度 |
| 3 | 🌧 **降水** | 雨滴/雪花粒子系统 | 降水概率（大字）、累积量、分钟级时间轴（简化） |
| 4 | 🌫 **空气** | 雾/粒子密度可视化（AQI → 颜色渐变） | AQI 数值（大字）+等级色标、紫外线 UV 指数、能见度 |

### 维度切换动画

```swift
// TabView(.page) 实现左右滑动，自动带弹性动画
// 每次切换时：
// 1. 3D 场景淡出旧维度 → 淡入新维度（crossFade 0.3s）
// 2. 数据区域从下方滑入
// 3. 指示点同步更新
TabView(selection: $currentDimension) {
    ForEach(WeatherDetailDimension.allCases) { dim in
        DimensionPanelView(dimension: dim, data: mockData)
            .tag(dim)
    }
}
.tabViewStyle(.page(indexDisplayMode: .never))
```

### 模拟数据（4个维度）

```swift
enum WeatherDetailDimension: CaseIterable, Identifiable {
    case temperature  // 温度
    case wind         // 风
    case precipitation // 降水
    case air          // 空气质量
    var id: Self { self }
}

// 各维度模拟值
let detailData = WeatherDetailData(
    temperature: .init(current: 72, feelsLike: 68, high: 79, low: 61),
    wind:        .init(speed: 12, direction: "WSW", gust: 18),
    precipitation: .init(probability: 20, accumulation: 0.0,
                         minutely: [(0,0),(5,0),(10,2),(15,8),(20,15),(25,5),(30,0)]),
    air:         .init(aqi: 42, level: "Good", uv: 4, uvLevel: "Moderate", visibility: 10)
)
```

---

## 6. SceneKit 动画系统

### 6.1 SceneKit 动画触发器（来自 `cedar-animation.json`）

| 触发事件 | 执行的动作 |
|---------------|-------------------|
| `sunIn`（白天） | planeColor → `161,157,104` · fog → `99,125,81 α:0.5` · crossFade `plane-night → plane-day` |
| `moonIn`（夜晚） | planeColor → `49,45,49` · fog → `49,45,49 α:0.75` · crossFade `plane-day → plane-night` |

### 6.2 天气状况 → 场景切换（页面 A）

| 天气状况 | 3D 模型节点 | 播放的动画 | 粒子效果 |
|-----------|--------------|-----------------|-----------|
| `clear`（晴） | `sun` 节点 | `anim_sun_in.dae` | 无 |
| `partlyCloudy` / `cloudy` | `cloud` 节点 | `anim_cloud_in.dae` | 无 |
| `rain` / `drizzle` | `cloud` + 雨粒子 | `anim_cloud_in.dae` | ✅ 雨粒子 |
| `snow` | `cloud` + 雪粒子 | `anim_cloud_in.dae` | ✅ 雪粒子 |
| `thunderstorm` | `cloud` + `bolt` | `anim_bolt.dae` | ✅ 雨粒子 |
| `fog` | fog 节点 | `anim_fog.dae` | 无 |

### 6.3 详情页各维度 3D 场景（页面 B）

| 维度 | 3D 方案（无需 .scn） | 颜色方案 |
|------|---------------------|---------|
| 温度 | `SCNSphere`（太阳）+ 动态点光源，云体用 `SCNSphere` 组合 | 橙→黄渐变 |
| 风 | 100+ 个 `SCNBox` 细条做流线粒子，`CABasicAnimation` 移动 | 青→白 |
| 降水 | `SCNParticleSystem` 雨滴，颜色/密度随降水量动态调整 | 蓝→深蓝 |
| 空气 | `SCNSphere` 浮动粒子群，密度/颜色映射 AQI（绿→红） | AQI 色标 |

> **备注**：详情页 3D 场景全部用 SceneKit 原语程序化构建，不依赖 `.dae` 文件，无需步骤 U-1 即可运行。

### 6.4 `WeatherSceneManager` API

```swift
class WeatherSceneManager: ObservableObject {
    func loadMainScene()                                // 加载页面 A 场景
    func setCondition(_ condition: WeatherCondition, animated: Bool)
    func setNightMode(_ isNight: Bool, animated: Bool)
    func pauseAnimations()
    func resumeAnimations()
}

class DimensionSceneBuilder {
    static func buildScene(for dimension: WeatherDetailDimension,
                           data: WeatherDetailData) -> SCNScene
    // 程序化构建各维度场景，无需外部 .dae 文件
}
```

---

## 7. 交付顺序（阶段）

### 阶段 0 · HomeView 入口接入（最先，无需任何资源）
- [ ] `HomeView.swift` — 新增 `weather` action + `isWeatherPresented` + `fullScreenCover`
- [ ] `WeatherMainView.swift` — 骨架占位视图（先跑通跳转）

### 阶段 1 · 数据层基础
- [ ] `WeatherCondition.swift` — 天气状况枚举 + SF Symbol 映射
- [ ] `MockWeatherData.swift` — 所有硬编码天气/逐小时/详情数据
- [ ] `WeatherDetailDimension.swift` — 4个维度枚举

### 阶段 2 · 页面 A UI（可先用 SF Symbol 占位 3D 场景）
- [ ] `WeatherMainView.swift` — 完整布局
- [ ] `WeatherConditionOverlay.swift` — 温度/城市叠加层
- [ ] `WeatherHourlyStrip.swift` — 逐小时横向预报条
- [ ] `WeatherDatePicker.swift` — 日期切换条

### 阶段 3 · 页面 B 旋转维度 UI
- [ ] `WeatherDetailView.swift` — TabView(.page) 容器
- [ ] `DimensionPanelView.swift` — 单面板布局（上 2/3 + 下 1/3）
- [ ] `DimensionDataView.swift` — 4个维度的数据展示区

### 阶段 4 · SceneKit 3D（页面 A + 页面 B 各维度）
- [ ] `WeatherSceneView.swift` — UIViewRepresentable 包装
- [ ] `WeatherSceneManager.swift` — 页面 A 场景（依赖步骤 U-1 完成后完整化）
- [ ] `DimensionSceneBuilder.swift` — 程序化构建页面 B 各维度场景（不依赖 .dae）
- [ ] `ParticleController.swift` — 雨/雪粒子
- [ ] `SceneConstants.swift`

### 阶段 5 · 完善
- [ ] 昼夜切换动画
- [ ] 维度切换过渡动画
- [ ] 可选：`cedar-animation.json` 驱动的颜色主题

---

## 8. 依赖项

天气模块**无需新增任何第三方依赖**，完全使用 ioscrmapp 现有框架：

| 框架 | 用途 |
|------|------|
| `SwiftUI` | 所有 UI 视图 |
| `SceneKit` | 3D 场景（页面 A + 页面 B 各维度） |
| `AVFoundation` | 可选音效（`.caf` 原生支持，无需转换） |
| `Foundation` | JSON 解析（cedar-animation.json） |

---

## 9. 备用计划（如果 `.scn` 导出失败）

页面 A 的主场景依赖 `.dae` 文件，但有完整备用方案：

| 备用方案 | 适用范围 | 方法 |
|----------|---------|------|
| **SceneKit 原语** | 页面 A 全部 | `SCNSphere`/`SCNBox` 组合构建太阳/云/雨场景，不用 `.dae` |
| **程序化粒子** | 雨/雪效果 | `SCNParticleSystem` 代码构建，不依赖 `precip-particle.png` |
| **SwiftUI 3D 错觉** | 降级方案 | `ZStack` + 阴影/模糊/3D rotate effect 伪造 3D 深度 |

> 页面 B 的 4 个维度场景**已经是程序化构建**，完全不依赖任何 `.dae` 文件，步骤 U-1 未完成也能正常运行。

---

## 10. 快速启动清单

```
你（macOS 操作）：                          我（直接写代码）：
─────────────────────────────────────────  ──────────────────────────────────────
□ 步骤 U-1：导出 .scn → .dae（可延后）    □ 阶段 0：HomeView 入口接入
□ 步骤 U-2：转换 HEIC → PNG（可延后）     □ 阶段 1：数据层基础
□ 步骤 U-3：将 .dae + PNG 拖入 Xcode     □ 阶段 2：页面 A UI
  （在阶段 4 SceneKit 完成前可不做）       □ 阶段 3：页面 B 旋转维度 UI
                                          □ 阶段 4：SceneKit 3D（部分不依赖 .dae）
                                          □ 阶段 5：动画完善
```

---

*计划版本 2.0 · 2026年4月（基于 ioscrmapp 现有项目结构调整）*
*应用参考：Not Boring Weather by Not Boring Software — 仅供学习使用*
