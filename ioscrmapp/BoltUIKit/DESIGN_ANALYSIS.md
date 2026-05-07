# iOS CRM App — 意图识别 & 设计系统 架构分析

> 生成日期: 2026-05-04 | 目标: 为后续架构评审、重构决策、新人 Onboarding 提供完整参考

---

## 目录

1. [意图识别系统](#1-意图识别系统)
   - 1.1 [整体架构](#11-整体架构)
   - 1.2 [意图类型全量目录](#12-意图类型全量目录)
   - 1.3 [三层识别管线](#13-三层识别管线)
   - 1.4 [信号融合策略](#14-信号融合策略)
   - 1.5 [ONB 人格画像子系统](#15-onb-人格画像子系统)
   - 1.6 [旅行意图 → UI 路由链路](#16-旅行意图--ui-路由链路)
2. [BoltUIKit 设计系统](#2-boltuikit-设计系统)
   - 2.1 [设计哲学](#21-设计哲学)
   - 2.2 [文件组织结构](#22-文件组织结构)
   - 2.3 [设计令牌体系 (BoltTheme v2)](#23-设计令牌体系-boltTheme-v2)
   - 2.4 [基础组件层](#24-基础组件层)
   - 2.5 [业务组件层](#25-业务组件层)
   - 2.6 [组件关系图](#26-组件关系图)
   - 2.7 [集成点: AIChatView](#27-集成点-aichatview)
3. [关键设计决策与权衡](#3-关键设计决策与权衡)

---

## 1. 意图识别系统

### 1.1 整体架构

```
用户输入文本
    │
    ▼
┌──────────────────────────────────────────────────────┐
│              IntentRecognitionService                 │
│  (DefaultIntentRecognitionService)                    │
│                                                      │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────┐ │
│  │ Layer 1     │  │ Layer 2      │  │ Layer 3     │ │
│  │ Local Match │─▶│ CoreML+Signal│─▶│ Remote AI   │ │
│  │ (关键词/规则) │  │ Fusion       │  │ (语义理解)   │ │
│  └─────────────┘  └──────────────┘  └─────────────┘ │
│                                                      │
│  ┌─────────────────────────────────────────────────┐ │
│  │           ONB Intent Fusion Service             │ │
│  │   (人格画像并行识别 + 商业参数增强)                 │ │
│  └─────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────┘
    │
    ▼
IntentRecognitionResult → IntentRoutingService → DomainFlow → AIChatView
```

**核心服务文件:**

| 文件 | 职责 |
|------|------|
| `Services/IntentRecognitionService.swift` | 三层识别管线编排（558 行） |
| `Services/CoreMLIntentClassifier.swift` | NLModel 本地文本分类器（72 行） |
| `Services/IntentSignalFusion.swift` | 规则+CoreML 信号融合（110 行） |
| `Services/IntentClassifierServicing.swift` | 分类器协议+配置+模型描述符 |
| `Utilities/IntentConfidenceCalculator.swift` | 置信度合并、高风险调整、确认逻辑 |
| `Services/ONBPersonaClassifierService.swift` | ONB 人格画像 CoreML 分类器 |
| `Services/ONBIntentFusionService.swift` | 意图+人格融合、路由映射 |

### 1.2 意图类型全量目录

**UserIntentType** (`Modules/AI/Models/IntentModels.swift:6`):

| 分类 | 枚举值 | 中文 | 导航目标 |
|------|--------|------|----------|
| **电信业务** | `balanceInquiry` | 查询余额 | `.home` |
| | `dataUsageQuery` | 查询流量 | `.home` |
| | `voiceUsageQuery` | 查询语音用量 | `.home` |
| | `smsUsageQuery` | 查询短信用量 | `.home` |
| | `rechargeAccount` | 账户充值 | `.recharge` |
| | `viewOffers` | 查看优惠 | `.offers` |
| | `subscribeOffer` | 订阅套餐 | `.offers` |
| | `viewBill` | 查看账单 | `.billing` |
| | `accountHelp` | 账户帮助 | `.me` |
| **支付** | `makePayment` | 进行支付 | `.billing` |
| | `paymentHistory` | 支付历史 | `.billing` |
| | `paymentStatus` | 支付状态 | `.billing` |
| **行程** | `itineraryQuery` | 行程查询 | `nil`(不直接导航) |
| | `flightInfo` | 航班信息 | `nil` |
| | `hotelInfo` | 酒店信息 | `nil` |
| **通用** | `generalQuestion` | 一般问题 | `nil` |
| | `navigationIntent` | 导航意图 | `nil` |
| | `unknown` | 未知意图 | `nil` |

**IntentCategory** 分组（`IntentModels.swift:280`）: `telecomBusiness` / `payment` / `itinerary` / `general` / `navigation`

**关键设计点** — 行程类意图（`itineraryQuery`/`flightInfo`/`hotelInfo`）的 `defaultNavigationTarget` 返回 `nil`，不走直接 Tab 跳转，而是进入 `BoltDomainFlow.travel` 富交互流程。其他意图直接跳转到对应 Tab 页。

### 1.3 三层识别管线

**`IntentRecognitionServicing` 协议** (`IntentRecognitionService.swift:11`):

```swift
protocol IntentRecognitionServicing: Sendable {
    func localMatch(text: String, language: AppLanguage) async -> IntentRecognitionResult?
    func aiSemanticMatch(text: String, context: AIChatContext,
                         conversationHistory: [AIChatMessage]) async throws -> IntentRecognitionResult
    func recognizeIntent(text: String, context: AIChatContext,
                         conversationHistory: [AIChatMessage],
                         language: AppLanguage) async throws -> IntentRecognitionResult
}
```

**DefaultIntentRecognitionService.recognizeIntent 实际执行流程**（重写了协议默认实现，`IntentRecognitionService.swift:228`）:

```
1. localMatch  →  LocalIntentMatcher（关键词/规则匹配）
2. classifier?.classify  →  CoreMLIntentClassifier（NLModel 本地推理）
3. fusion.fuse(ruleResult, coreMLCandidate)  →  IntentSignalFusion
4. 根据 rolloutMode 决定：
   ├─ .disabled / .shadow  →  仅用 localMatch（高置信度阈值）
   └─ .fusedAuthoritative  →  使用融合结果
5. 若结果为 unknown 或 requiresRemoteFallback：
   └─ aiSemanticMatch  →  远端 AI API（JSON 格式意图分类 prompt）
6. onbFusionService.fuse  →  注入 ONB 人格画像增强参数
7. applyBusinessConfidencePolicies  →  置信度阈值检查 + 确认动作注入
```

**CoreML 分类器** (`CoreMLIntentClassifier.swift:4`):
- 使用 `NaturalLanguage.NLModel`，从 `IntentClassifier.mlmodelc` 加载
- 按 `UserIntentType.rawValue` 映射预测标签
- 低置信度（低于 `minimumAcceptedCoreMLConfidence`）触发 `requiresConfirmation`
- Actor 隔离，懒加载模型，缓存 NLModel 实例

**远端 AI 分类 prompt** (`IntentRecognitionService.swift:152-186`):
- 要求 AI 返回纯 JSON（不包 markdown fence）
- JSON 结构: `intent_type`, `confidence`, `navigation_target`, `business_parameters`, `requires_confirmation`, `alternative_intents`
- 包含详细的分类规则（如 `data_usage_query` vs `view_offers` 的区分）

### 1.4 信号融合策略

**IntentSignalFusion** (`IntentSignalFusion.swift:11`):

```
规则结果 + CoreML结果
    │
    ├─ 两者一致  →  置信度取平均值，source = .fusion
    │
    ├─ 两者冲突  →  路由到 IntentConfidenceCalculator
    │               ├─ 高风险意图(.subscribeOffer/.makePayment): 取较高置信度一方
    │               └─ 普通意图: AI结果优先（若AI置信度≥0.7）
    │
    └─ 仅一方有值  →  直接使用该结果
```

**IntentConfidenceCalculator** (`IntentConfidenceCalculator.swift`):
- `minimumConfidenceThreshold = 0.70` — 低于此值触发确认流程
- `highConfidenceThreshold = 0.85` — 高于此值可跳过确认
- 对 `.subscribeOffer` / `.makePayment` 强制要求确认（防止错误扣费）

**RolloutMode 三种模式** (`IntentClassifierConfiguration`):
| 模式 | 行为 |
|------|------|
| `.disabled` | 仅规则匹配 |
| `.shadow` | 仅规则匹配（融合结果仅记录日志不采用） |
| `.fusedAuthoritative` | 全量融合管线 |

### 1.5 ONB 人格画像子系统

ONB（Onboarding）系统在意图识别之外**并行**对用户进行人格画像分类，结果用于增强商业参数。

**ONBPersonaIntent** (`ONBPersonaModels.swift:6`) — 22 种人格:

| ONB 阶段 | 人格意图 | 推荐动作 |
|----------|----------|----------|
| **ONB-02** 生活方式 | `travelFrequent` | 推荐漫游套餐+高数据+国际分钟 |
| | `businessUsage` | 同 travelFrequent |
| | `gamingHeavy` | 推荐高数据计划+低延迟 |
| | `videoStreamingHeavy` | 推荐无限计划+娱乐附加 |
| | `socialCommunicationHeavy` | 推荐社交数据包 |
| | `budgetSensitive` | 推荐最佳性价比计划 |
| | `studentUsage` | 推荐学生特惠 |
| | `familyUsage` | 推荐家庭共享计划 |
| **ONB-03** 计划选择 | `highDataUsage` | 推荐无限/高数据计划 |
| | `unlimitedPreference` | 推荐无限计划 |
| | `highVoiceUsage` | 推荐高语音计划 |
| | `roamingRequired` | 打开漫游支持流程 |
| | `budgetOptimization` | 推荐最优性价比 |
| | `flexiblePlanPreference` | 展示灵活计划选项 |
| **ONB-06** 激活后支持 | `activationIssue` | 激活状态检查 |
| | `networkIssue` | 网络故障排除 |
| | `billingQuery` | 打开账单摘要 |
| | `esimSetup` | eSIM 设置指南 |
| | `planChange` | 计划变更流程 |
| | `dataUsageQuery` | 打开数据用量页面 |
| | `roamingSupport` | 漫游支持流程 |
| | `addFamilyMember` | 推荐家庭计划+附加SIM |

**并行融合架构** (`ONBIntentFusionService.swift:7`):
```
用户输入
    ├─▶ IntentRecognitionService.recognizeIntent()     → IntentRecognitionResult
    └─▶ ONBPersonaClassifierService.classifyPersona()  → ONBPersonaResult
              │
              ▼
         ONBIntentFusionService.fuse()
              │
              ▼
         IntentFusionResult {
             intentResult,
             personaResult,
             enhancedBusinessParameters: [
                 "onb_persona", "onb_stage",
                 "persona_confidence", "recommendation_hint",
                 "recommended_actions"
             ]
         }
```

**ONBPersonaRouter** (`ONBIntentFusionService.swift:85`): 将 22 种人格映射为 18 种 `ONBPersonaAction`。

### 1.6 旅行意图 → UI 路由链路

完整链路（从用户输入到 UI 渲染）:

```
用户: "I want to go to Dubai"
    │
    ▼
IntentRecognitionService.recognizeIntent()
    → intentType: .itineraryQuery (或 .flightInfo / .hotelInfo)
    → navigationTarget: nil (不直接跳转)
    │
    ▼
IntentRoutingService
    → 创建 BoltTravelFlowContext:
        destination: "Dubai"
        transportMode: .flight
        suggestedReplies: [...]
    → 返回 .travel(flowContext)
    │
    ▼
AIChatViewModel.activeDomainFlow = .travel(context)
    │
    ▼
AIChatView.swift:1172  case .travel(let context):
    │
    ├─ context.destination != nil
    │   → 创建 TravelIntent
    │   → 渲染 BoltTravelShowcase:
    │       ├─ BoltHeroTravelCard (Hero 主视觉)
    │       ├─ BoltFlightList    (航班建议)
    │       ├─ BoltHotelGrid     (酒店建议)
    │       ├─ BoltActivityList  (体验建议)
    │       └─ BoltPackageList   (套餐建议)
    │
    └─ context.destination == nil
        ├─ ticketPageErrorMessage  → BoltResultCard (错误卡片)
        ├─ isResolvingTicketPage   → BoltFormCard (加载中)
        ├─ ticketPageURL != nil    → BoltEmbeddedWebCard (WebView)
        ├─ followUpQuestion != nil → BoltFollowUpCard (追问)
        └─ else                    → BoltActionGroup (双CTA按钮)
```

**BoltDomainFlow 定义** (`AIChatModels.swift:386`):
```swift
enum BoltDomainFlow {
    case offers(BoltOfferFlowContext)
    case roaming(BoltOfferFlowContext)
    case recharge(BoltRechargeFlowContext)
    case billing(BoltBillingFlowContext)
    case payment(BoltPaymentFlowContext)
    case travel(BoltTravelFlowContext)   // ← 旅行域
    case balance(BoltInfoCard)
    case usage(BoltInfoCard)
    case serviceRequest(BoltServiceFlowContext)
}
```

---

## 2. BoltUIKit 设计系统

### 2.1 设计哲学

**核心原则（v2 旅行场景设计语言）:**

| 维度 | 设计决策 | 实现方式 |
|------|----------|----------|
| **色彩** | 暖色调旅行体系 | 金色/琥珀色/日落渐变为主，深海蓝/天空蓝/森林绿为辅 |
| **材质** | 玻璃态 + 多层深度 | `.ultraThinMaterial` + 半透明叠加 + 渐变描边 |
| **阴影** | 三级深度系统 | near(4pt) → mid(12pt) → far(30pt) |
| **排版** | 全圆角字体 | `.system(.rounded)` 四档: display/heading/body/caption |
| **动效** | 呼吸式微动效 | 20s 周期的 phase 动画 + spring 弹性曲线 |
| **几何** | 抽象几何装饰 | Canvas 网格线 + offset Circle + RadialGradient 光晕 |
| **状态** | 全状态覆盖 | EmptyState / LoadingState / ErrorState / Normal |

**与 v1 的核心差异:**
- v1 使用单一冷色调（`0x3CD1FF`），v2 改为暖色调旅行体系
- v1 使用简单 `RoundedRectangle` 背景，v2 使用三层阴影 + 渐变描边
- v1 无动效，v2 加入出现动画（spring 弹性）+ 呼吸光点
- v1 无抽象装饰，v2 引入 `BoltTravelDreamscape` 几何艺术

### 2.2 文件组织结构

```
ioscrmapp/BoltUIKit/
├── Core/                               # 基础层（设计令牌 + 通用组件）
│   ├── BoltTheme.swift                 # 设计令牌（32 色 + 间距 + 阴影 + 动效 + 排版）
│   └── BoltBaseCard.swift             # 5 个基础组件 + 2 个按钮
│
├── Travel/                             # 业务层（旅行场景）
│   ├── Models/
│   │   └── TravelModels.swift          # 3 个数据模型 + 多语言
│   └── Components/
│       ├── BoltTravelDreamscape.swift  # 梦境抽象几何背景
│       ├── BoltTravelCard.swift        # Hero 主视觉卡片
│       ├── BoltTravelShowcase.swift    # 展示容器 + Empty/Loading 状态
│       ├── BoltFlightCard.swift        # 航班卡片 + 航班列表
│       ├── BoltHotelCard.swift         # 酒店卡片 + 酒店网格
│       ├── BoltActivityCard.swift      # 体验卡片 + 体验列表
│       └── BoltPackageCard.swift       # 套餐卡片 + 套餐列表
```

**总计: 10 个源文件, ~1200 行代码**

### 2.3 设计令牌体系 (BoltTheme v2)

**`BoltTheme`** (`Core/BoltTheme.swift`) — 纯静态结构体，无实例化:

```
BoltTheme
├── 品牌色 (8)
│   ├── gold       #D4A853  主暖金色
│   ├── amber      #F5A623  琥珀色
│   ├── sunset     #FF6B4A  落日渐变终点
│   ├── rose       #E8735A  玫瑰暖色
│   ├── oceanDeep  #1B4F72  深海蓝
│   ├── skyBlue    #5DADE2  天空蓝
│   ├── forest     #229954  森林绿
│   └── lavender   #A569BD  薰衣草紫
│
├── 渐变预设 (4)
│   ├── gradientGold   [0xF9D56E, 0xF5A623, 0xE8735A]
│   ├── gradientOcean  [0x1B4F72, 0x2E86C1, 0x5DADE2]
│   ├── gradientDusk   [0x2C3E50, 0x4A235A, 0x8E44AD]
│   └── gradientWarm   [0xFF6B4A, 0xF5A623, 0xD4A853]
│
├── 背景层级 (5)
│   ├── surfaceBase      white.opacity(0.04)
│   ├── surfaceRaised    white.opacity(0.06)
│   ├── surfaceGlass     white.opacity(0.08)
│   ├── surfaceGlassHover white.opacity(0.14)
│   └── surfaceGlow      white.opacity(0.10)
│
├── 文字层级 (4)
│   ├── textPrimary    white.opacity(0.95)
│   ├── textSecondary  white.opacity(0.65)
│   ├── textTertiary   white.opacity(0.40)
│   └── textInverse    black.opacity(0.85)
│
├── 边框 (3)
│   ├── borderSubtle   white.opacity(0.10)
│   ├── borderMedium   white.opacity(0.18)
│   └── borderAccent   white.opacity(0.28)
│
├── 间距系统 (8)
│   spacing3xs(2) → 2xs(4) → Xs(8) → Sm(12) → Md(16) → Lg(24) → Xl(32) → 2xl(48) → 3xl(64)
│
├── 圆角 (4)
│   radiusSm(8) → radiusMd(14) → radiusLg(20) → radiusXl(28)
│
├── 阴影系统 (3)
│   ├── shadowNear  black.opacity(0.20)   // 近距锐利阴影
│   ├── shadowMid   black.opacity(0.12)   // 中距扩散阴影
│   └── shadowFar   black.opacity(0.06)   // 远距环境阴影
│
├── 动效 (4)
│   ├── springEase     response:0.40 damping:0.72
│   ├── springBounce   response:0.45 damping:0.60
│   ├── durationFast   0.18s
│   ├── durationNormal 0.30s
│   └── durationSlow   0.50s
│
└── 排版 (4)
    ├── displayFont(size)  .bold.rounded
    ├── headingFont(size)  .semibold.rounded
    ├── bodyFont(size)     .medium.rounded
    └── captionFont(size)  .regular.rounded
```

### 2.4 基础组件层

**`BoltBaseCard.swift`** — 6 个通用组件 + 2 个按钮组件:

| 组件 | 类型 | 用途 | 关键特性 |
|------|------|------|----------|
| `BoltGlassSurface` | 容器 | 玻璃态基底卡片 | 3 层阴影 + 渐变描边(stroke) + `surfaceGlass` 背景 |
| `BoltElevatedCard` | 容器 | 悬浮卡片 | 顶部 RadialGradient 描边 + glow shadow |
| `BoltSectionHeader` | 排版 | 分区标题 | 金色文字 + 图标 + 装饰线 |
| `BoltDetailRow` | 排版 | 键值行 | 金色图标 + label/value 布局 |
| `BoltBadge` | 标签 | 状态徽章 | 4 种风格: success/info/premium/gold |
| `BoltGlowButton` | 按钮 | 主 CTA | 渐变填充胶囊 + 全宽 + 图标 |
| `BoltGhostButton` | 按钮 | 次 CTA | 玻璃态胶囊 + 渐变描边 |

**BoltGlassSurface 实现细节:**
```
┌─────────────────────────────────────────┐
│  content.padding(padding)                │  ← 内容层
│  .background(                            │
│    RoundedRectangle.fill(surfaceGlass)   │  ← 玻璃填充
│    .overlay(LinearGradient stroke)       │  ← 渐变描边
│  )                                       │
│  .clipShape(RoundedRectangle)            │  ← 裁剪
│  .shadow(shadowNear, radius:4, y:2)      │  ← 近距阴影
│  .shadow(shadowMid,  radius:12, y:8)     │  ← 中距阴影
│  .shadow(shadowFar,  radius:30, y:20)    │  ← 远距阴影
└─────────────────────────────────────────┘
```

**BoltBadge.Style 颜色映射:**
| Style | 背景 | 前景 |
|-------|------|------|
| `.success` | `forest.opacity(0.18)` | `forest` |
| `.info` | `skyBlue.opacity(0.18)` | `skyBlue` |
| `.premium` | `lavender.opacity(0.18)` | `lavender` |
| `.gold` | `gold.opacity(0.18)` | `gold` |

### 2.5 业务组件层

#### BoltTravelDreamscape — 梦境抽象背景

**用途:** 替代普通渐变/图片占位，为每个目的地创建独特的抽象几何视觉。

**交通方式调色板:**
| 交通方式 | primary | accent | deep |
|----------|---------|--------|------|
| `.flight` | `skyBlue` | `gold` | `oceanDeep` |
| `.train` | `forest` | `amber` | `0x1B3A2D` |
| `.bus` | `amber` | `sunset` | `0x3D2010` |

**5 层视觉结构:**
1. 深邃底色 (palette.deep)
2. 大环形 RadialGradient 光晕 (palette.accent) — 带 phase 偏移
3. 两个交叉 `Circle().stroke` 环形 — 不同方向/速度的 phase 偏移
4. 第二个大 RadialGradient 光晕 (palette.primary) — 不同位置
5. `GeometryGrid` Canvas 网格线 (12 密度) — 带 RadialGradient mask
6. 三个 pulsating 光点 — 不同位置/颜色/缩放节奏
7. 目的地 Capsule 叠加层 — `.ultraThinMaterial` + 金色 accent 圆点

**动效:** `phase` 从 0 → 2π，20s 线性重复。各层使用不同频率的 sin/cos 产生视差运动感。

#### BoltHeroTravelCard (alias: BoltTravelCard) — Hero 主视觉

```
┌─ BoltGlassSurface ──────────────────────────┐
│ ┌─ ZStack(alignment: .bottom) ────────────┐ │
│ │ ┌─ BoltTravelDreamscape ──────────────┐ │ │
│ │ │  高度 180pt, clipped                 │ │ │
│ │ └──────────────────────────────────────┘ │ │
│ │ ┌─ LinearGradient 底部遮罩 ────────────┐ │ │
│ │ │  clear → black(0.55) → black(0.85)   │ │ │
│ │ └──────────────────────────────────────┘ │ │
│ │ ┌─ 目的地信息层 ───────────────────────┐ │ │
│ │ │  "Dubai, UAE"                        │ │ │
│ │ │  📅 "Apr 10 - Apr 15"                │ │ │
│ │ └──────────────────────────────────────┘ │ │
│ └──────────────────────────────────────────┘ │
│ ┌─ 信息层 ────────────────────────────────┐ │
│ │  SummaryPills: ✈Flight · 🌙5 nights · 👥2│ │
│ │  ─── Divider ───                        │ │
│ │  from  $299 - $599    [per person]      │ │
│ │  ─── Divider ───                        │ │
│ │  [✈ Explore Flights]  [🛏 Hotels]      │ │
│ └──────────────────────────────────────────┘ │
└──────────────────────────────────────────────┘
```

**出现动效:** opacity 0→1 + offset y 30→0 + springEase

#### 四种建议卡片对比

| 维度 | BoltFlightCard | BoltHotelCard | BoltActivityCard | BoltPackageCard |
|------|---------------|---------------|-----------------|-----------------|
| **基底** | `BoltGlassSurface` | `BoltGlassSurface` | `BoltGlassSurface` | `BoltElevatedCard` |
| **视觉钩子** | 左侧 FlightRouteIcon (圆点+虚线+飞机) | 顶部微型渐变画布 (90pt) + 网格线 | 左侧 3px 渐变彩条 (gold→amber→sunset) | 顶部渐变彩带 (60pt, gold/lavender/skyBlue) + 装饰圆 |
| **特殊装饰** | - | RadialGradient 光晕 + HotelGrid | sparkles 图标 + 类型标签 | 偏移 Circle 装饰 + PackageChip |
| **价格样式** | displayFont(17) gold | displayFont(17) gold | displayFont(16) gold | displayFont(24) gold |
| **CTA 样式** | 无独立 CTA | 无独立 CTA | 渐变 Capsule (gold→amber) | 渐变 Capsule (gold→sunset) |
| **列表容器** | `BoltFlightList` (VStack) | `BoltHotelGrid` (LazyVGrid 2列) | `BoltActivityList` (VStack) | `BoltPackageList` (VStack) |

#### BoltTravelShowcase — 展示容器

**职责:** 组合 Hero + 4 种建议列表，按 `intent.suggestions` 的 type 过滤分发。

**附带组件:**
- `BoltTravelEmptyState` — 无结果空状态 (飞机图标 + 搜索按钮)
- `BoltTravelLoadingState` — 加载中 (飞机摇摆动画)

### 2.6 组件关系图

```
BoltTravelShowcase
├── BoltHeroTravelCard (alias: BoltTravelCard)
│   ├── BoltGlassSurface
│   │   └── BoltTheme (tokens)
│   ├── BoltTravelDreamscape
│   │   ├── GeometryGrid (Canvas)
│   │   ├── RadialGradient ×2
│   │   ├── Circle().stroke ×2
│   │   └── Circle().blur (光点 ×3)
│   ├── SummaryPill ×3
│   ├── BoltBadge(.gold)
│   ├── BoltGlowButton ("Explore Flights")
│   └── BoltGhostButton ("Hotels")
│
├── BoltFlightList
│   └── BoltFlightCard ×N
│       ├── BoltGlassSurface
│       ├── FlightRouteIcon (Circle×2 + CurvedDashedLine)
│       └── BoltBadge(.info)
│
├── BoltHotelGrid
│   └── BoltHotelCard ×N
│       ├── BoltGlassSurface
│       ├── HotelGrid (Canvas)
│       └── BoltBadge(.premium)
│
├── BoltActivityList
│   └── BoltActivityCard ×N
│       ├── BoltGlassSurface
│       ├── RoundedRectangle 渐变彩条
│       └── Capsule CTA
│
├── BoltPackageList
│   └── BoltPackageCard ×N
│       ├── BoltElevatedCard
│       ├── PackageChip ×3
│       └── Capsule CTA
│
├── BoltTravelEmptyState
│   └── BoltGlassSurface + BoltTheme.gold
│
└── BoltTravelLoadingState
    └── BoltGlassSurface + 飞机摇摆动画
```

### 2.7 集成点: AIChatView

**位置:** `Modules/AI/Views/AIChatView.swift:1172`

**触发条件:** `viewModel.activeDomainFlow` 匹配 `.travel(let context)`

**数据流:**
```
BoltTravelFlowContext
    ├── destination: String?         → TravelIntent.destination
    ├── transportMode: BoltTravelTransportMode? → TravelTransportMode
    ├── departureDateText: String?   → (未直接使用)
    ├── suggestedReplies: [String]   → BoltFollowUpCard
    ├── ticketPageURL: URL?          → BoltEmbeddedWebCard
    ├── isResolvingTicketPage: Bool  → BoltFormCard (加载态)
    └── ticketPageErrorMessage: String? → BoltResultCard (错误态)
```

**两个 CTA 回调:**
1. `onExploreFlights` → `viewModel.openTravelTicketsInBolt()` — 打开 Bolt 票务页面
2. `onExploreHotels` → `viewModel.openTravelOffersInBolt()` — 提交跟进建议获取优惠

---

## 3. 关键设计决策与权衡

### 决策 1: 意图识别三层架构 vs 单层 AI

**选择:** 三层（本地规则 → CoreML → 远端 AI）

**理由:**
- 本地规则: 0ms 延迟，覆盖高频明确意图（"查余额"、"充话费"）
- CoreML: <10ms 本地推理，离线可用，作为规则和 AI 之间的信号融合层
- 远端 AI: 处理复杂语义，兜底所有未覆盖场景

**代价:** 三套分类逻辑需维护一致性，`classificationPrompt` 字符串与 `NLModel` 标签需同步更新。

### 决策 2: ONB 人格画像与意图识别并行

**选择:** 人格画像与意图识别完全解耦，并行执行，在最后一步融合。

**理由:** 人格画像（用户是谁）与意图（用户要做什么）是正交维度，解耦后各自模型可独立迭代。

**代价:** 增加 `ONBIntentFusionService` 和 `ONBPersonaRouter` 两层抽象，管线复杂度上升。

### 决策 3: 行程意图不走导航跳转

**选择:** `.itineraryQuery/.flightInfo/.hotelInfo` 的 `defaultNavigationTarget = nil`

**理由:** 旅行是富交互场景（多卡片、多建议、WebView 嵌入），不是简单的 Tab 切换。进入 `BoltDomainFlow.travel` 后由 AIChatView 渲染完整 BoltUIKit 组件树。

**代价:** AIChatView 中 travel case 分支逻辑较重（~80 行），包含多个子状态判断。

### 决策 4: 设计令牌纯静态 struct vs Theme protocol

**选择:** `struct BoltTheme { static let ... }` 纯静态常量

**理由:** 当前无主题切换需求（无深色/浅色模式切换），静态常量编译时内联，零运行时开销。

**扩展路径:** 若未来需多主题，可将 `BoltTheme` 改为 protocol，静态属性改为实例属性，注入 `@Environment(\.boltTheme)`。

### 决策 5: 组件即文件 vs 单文件多组件

**选择:** 每类业务卡片独立文件，相关列表容器同文件。

**理由:** 每类卡片有独立的视觉语言和私有辅助组件（如 `FlightRouteIcon`、`HotelGrid`、`PackageChip`），独立文件避免编译单元过大。

**边界:** `BoltBaseCard.swift` 集中了 7 个通用组件，这是合理的因为它们共享同一设计令牌依赖且每个组件都很小（<50 行）。

### 决策 6: Preview 数据硬编码 vs Mock Service

**选择:** 每个组件的 `#Preview` 中硬编码 `TravelSuggestion(...)` 数据

**理由:** SwiftUI Preview 需要编译时可用数据，Mock Service 需要运行时依赖注入。

**改进方向:** 可抽取 `TravelSuggestion.preview*` 静态工厂方法统一管理 Preview 数据。

---

## 附录: 文件清单

| 文件路径 | 行数 | 职责 |
|----------|------|------|
| `BoltUIKit/Core/BoltTheme.swift` | 87 | 设计令牌 |
| `BoltUIKit/Core/BoltBaseCard.swift` | 187 | 7通用组件+2按钮 |
| `BoltUIKit/Travel/Models/TravelModels.swift` | 127 | 数据模型+多语言 |
| `BoltUIKit/Travel/Components/BoltTravelDreamscape.swift` | 147 | 梦境几何背景 |
| `BoltUIKit/Travel/Components/BoltTravelCard.swift` | 176 | Hero主卡片 |
| `BoltUIKit/Travel/Components/BoltTravelShowcase.swift` | 166 | 展示容器+状态 |
| `BoltUIKit/Travel/Components/BoltFlightCard.swift` | 126 | 航班卡片 |
| `BoltUIKit/Travel/Components/BoltHotelCard.swift` | 138 | 酒店卡片 |
| `BoltUIKit/Travel/Components/BoltActivityCard.swift` | 114 | 体验卡片 |
| `BoltUIKit/Travel/Components/BoltPackageCard.swift` | 141 | 套餐卡片 |
| `Services/IntentRecognitionService.swift` | 637 | 意图识别主服务 |
| `Services/CoreMLIntentClassifier.swift` | 72 | CoreML分类器 |
| `Services/IntentSignalFusion.swift` | 110 | 信号融合 |
| `Services/ONBPersonaClassifierService.swift` | 109 | 人格分类器 |
| `Services/ONBIntentFusionService.swift` | 147 | 人格+意图融合 |
| `Utilities/IntentConfidenceCalculator.swift` | 150 | 置信度计算 |
| `Modules/AI/Models/IntentModels.swift` | 304 | 意图类型枚举 |
| `Modules/AI/Models/ONBPersonaModels.swift` | 180 | 人格画像模型 |
| `Modules/AI/Models/AIChatModels.swift` | ~420 | AI聊天模型+DomainFlow |
| `Modules/AI/Views/AIChatView.swift` | ~3700 | 聊天UI(集成点) |
