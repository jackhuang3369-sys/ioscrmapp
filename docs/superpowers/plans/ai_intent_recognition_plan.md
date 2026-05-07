---
title: AI 意图识别系统实施计划
version: 1.0
created: 2026-05-02
status: draft
---

# AI 意图识别系统实施计划

## 1. 概述

### 1.1 目标

将现有的硬编码关键词匹配意图识别系统升级为基于 AI 的动态意图识别系统，提升用户体验和识别准确率。

### 1.2 当前状态

**现有实现**（`AIChatViewModel.swift` 第 57-99 行）：
- ✅ 已有基础意图识别方法 `directNavigationTarget`
- ✅ 已有硬编码关键词列表（英文、中文、阿拉伯语）
- ✅ 已有导航目标枚举 `AIChatNavigationTarget`
- ✅ 已有事件分类结构 `AIChatOfferAgentEvent`
- ✅ 已有元数据结构 `AIChatRequestMetadata`

**问题**：
- ❌ 硬编码关键词覆盖有限
- ❌ 无法处理语义相似但措辞不同的用户输入
- ❌ 缺少意图置信度评估
- ❌ 缺少多意图识别和处理
- ❌ 缺少上下文关联意图理解

### 1.3 目标状态

构建分层意图识别系统：
- **第一层**：本地快速匹配（保留现有硬编码，作为 fallback）
- **第二层**：AI语义理解（调用后端 AI 服务）
- **第三层**：上下文关联分析（多轮对话历史）

## 2. 架构设计

### 2.1 模块结构

```
ioscrmapp/ioscrmapp/Modules/AI/
├── Models/
│   ├── AIChatModels.swift           (现有文件，需扩展)
│   ├── IntentModels.swift           (新增：意图识别模型)
│   └── IntentClassificationModels.swift (新增：分类和置信度模型)
├── ViewModels/
│   ├── AIChatViewModel.swift        (现有文件，需重构)
│   └── IntentRecognitionViewModel.swift (新增：意图识别专用 ViewModel)
├── Views/
│   ├── AIChatView.swift             (现有文件，无需改动)
│   └── IntentFeedbackView.swift     (新增：意图确认 UI)
├── Services/
│   ├── AIChatServicing.swift        (现有文件，需扩展)
│   ├── IntentRecognitionServicing.swift (新增：意图识别服务协议)
│   └── DefaultIntentRecognitionService.swift (新增：默认实现)
└── Utilities/
    ├── IntentNormalizer.swift       (新增：文本预处理)
    └── IntentConfidenceCalculator.swift (新增：置信度计算)
```

### 2.2 数据流设计

```swift
用户输入
    ↓
文本预处理（IntentNormalizer）
    ↓
本地快速匹配（第一层）
    ↓ [未匹配]
AI 语义理解请求（第二层）
    ↓
意图分类 + 置信度计算
    ↓
多意图处理决策
    ↓
导航目标 / 业务动作映射
    ↓
执行或请求用户确认
```

## 3. 核心模型设计

### 3.1 意图类型枚举

```swift
enum UserIntentType: String, Codable, Sendable, Equatable {
    // 电信业务意图
    case balanceInquiry = "balance_inquiry"
    case rechargeAccount = "recharge_account"
    case viewOffers = "view_offers"
    case subscribeOffer = "subscribe_offer"
    case viewBill = "view_bill"
    case accountHelp = "account_help"

    // 支付相关意图
    case makePayment = "make_payment"
    case paymentHistory = "payment_history"
    case paymentStatus = "payment_status"

    // 行程相关意图（保留现有）
    case itineraryQuery = "itinerary_query"
    case flightInfo = "flight_info"
    case hotelInfo = "hotel_info"

    // 通用意图
    case generalQuestion = "general_question"
    case navigationIntent = "navigation_intent"
    case unknown = "unknown"
}
```

### 3.2 意图识别结果模型

```swift
struct IntentRecognitionResult: Codable, Sendable, Equatable {
    let intentType: UserIntentType
    let confidence: Double // 0.0 ~ 1.0
    let navigationTarget: AIChatNavigationTarget?
    let businessParameters: [String: String]
    let requiresConfirmation: Bool
    let suggestedActions: [IntentAction]
    let alternativeIntents: [AlternativeIntent]

    var isHighConfidence: Bool {
        confidence >= 0.85
    }

    var needsUserConfirmation: Bool {
        confidence < 0.7 || requiresConfirmation
    }
}

struct AlternativeIntent: Codable, Sendable, Equatable {
    let intentType: UserIntentType
    let confidence: Double
    let description: String
}

struct IntentAction: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let title: String
    let actionType: IntentActionType
    let parameters: [String: String]
}

enum IntentActionType: String, Codable, Sendable, Equatable {
    case navigate
    case executeBusinessFlow
    case requestMoreInfo
    case showConfirmationDialog
}
```

### 3.3 多意图识别模型

```swift
struct MultiIntentRecognitionResult: Codable, Sendable, Equatable {
    let primaryIntent: IntentRecognitionResult
    let secondaryIntents: [IntentRecognitionResult]
    let combinedNavigationTargets: [AIChatNavigationTarget]

    var hasMultipleIntents: Bool {
        !secondaryIntents.isEmpty
    }
}
```

## 4. 服务层设计

### 4.1 意图识别服务协议

```swift
protocol IntentRecognitionServicing: Sendable {
    /// 本地快速匹配（第一层）
    func localMatch(text: String, language: AppLanguage) async -> IntentRecognitionResult?

    /// AI 语义理解（第二层）
    func aiSemanticMatch(
        text: String,
        context: AIChatContext,
        conversationHistory: [AIChatMessage]
    ) async throws -> IntentRecognitionResult

    /// 综合意图识别（多层融合）
    func recognizeIntent(
        text: String,
        context: AIChatContext,
        conversationHistory: [AIChatMessage],
        language: AppLanguage
    ) async throws -> IntentRecognitionResult

    /// 批量意图识别（多意图场景）
    func recognizeMultiIntent(
        text: String,
        context: AIChatContext,
        conversationHistory: [AIChatMessage],
        language: AppLanguage
    ) async throws -> MultiIntentRecognitionResult
}
```

### 4.2 默认实现策略

```swift
final class DefaultIntentRecognitionService: IntentRecognitionServicing {
    private let aiChatService: any AIChatServicing
    private let localMatcher: LocalIntentMatcher
    private let confidenceCalculator: IntentConfidenceCalculator

    func recognizeIntent(...) async throws -> IntentRecognitionResult {
        // 第一层：本地快速匹配
        if let localResult = await localMatch(text: text, language: language),
           localResult.isHighConfidence {
            return localResult
        }

        // 第二层：AI 语义理解
        let aiResult = try await aiSemanticMatch(
            text: text,
            context: context,
            conversationHistory: conversationHistory
        )

        // 置信度评估和决策
        return confidenceCalculator.evaluate(aiResult, localResult)
    }
}
```

## 5. 实施阶段划分

### 阶段 1：模型层构建（2-3 天）

**目标**：建立核心数据模型

**任务清单**：
- [ ] 创建 `IntentModels.swift`（意图类型枚举）
- [ ] 创建 `IntentClassificationModels.swift`（识别结果模型）
- [ ] 扩展 `AIChatModels.swift`（添加多意图模型）
- [ ] 编写单元测试验证模型序列化/反序列化

**验收标准**：
- 所有模型支持 `Codable` 和 `Sendable`
- 单元测试覆盖率 ≥ 90%
- 编译无警告

### 阶段 2：服务层实现（3-4 天）

**目标**：实现意图识别核心逻辑

**任务清单**：
- [ ] 创建 `IntentRecognitionServicing.swift`（协议定义）
- [ ] 创建 `DefaultIntentRecognitionService.swift`（默认实现）
- [ ] 创建 `IntentNormalizer.swift`（文本预处理工具）
- [ ] 创建 `IntentConfidenceCalculator.swift`（置信度计算）
- [ ] 扩展 `AIChatServicing.swift`（添加意图识别端点）
- [ ] 编写集成测试验证服务调用

**验收标准**：
- 本地匹配响应时间 < 50ms
- AI 匹配响应时间 < 3s
- 置信度计算准确率 ≥ 85%
- 集成测试覆盖关键路径

### 阶段 3：ViewModel 集成（2-3 天）

**目标**：重构 ViewModel 支持新系统

**任务清单**：
- [ ] 创建 `IntentRecognitionViewModel.swift`（专用 ViewModel）
- [ ] 重构 `AIChatViewModel.swift` 的 `directNavigationTarget` 方法
- [ ] 添加意图识别状态管理（loading, success, error）
- [ ] 实现多意图处理流程
- [ ] 添加用户确认交互逻辑
- [ ] 编写 ViewModel 单元测试

**验收标准**：
- ViewModel 可独立测试（依赖注入）
- 状态转换逻辑清晰可追踪
- 用户确认 UI 交互流畅

### 阶段 4：UI 视图层（1-2 天）

**目标**：添加意图确认 UI

**任务清单**：
- [ ] 创建 `IntentFeedbackView.swift`（意图确认对话框）
- [ ] 添加多意图选择 UI
- [ ] 集成到 `AIChatView.swift`（不破坏现有 UI）
- [ ] 支持三语言本地化

**验收标准**：
- UI 设计符合现有风格
- 支持阿拉伯语 RTL 布局
- 无 UI 闪烁或布局冲突

### 阶段 5：测试与优化（2-3 天）

**目标**：系统测试和性能优化

**任务清单**：
- [ ] 编写 E2E 测试（SmokeTests 目录）
- [ ] 性能测试（响应时间、内存占用）
- [ ] 准确率测试（真实用户数据模拟）
- [ ] 优化本地匹配关键词列表
- [ ] 优化 AI 提示词（prompt engineering）

**验收标准**：
- E2E 测试覆盖关键用户路径
- 本地匹配命中率 ≥ 40%
- AI 匹配准确率 ≥ 80%
- 整体响应时间 ≤ 3s

### 阶段 6：文档与交付（1 天）

**目标**：完成文档和交付准备

**任务清单**：
- [ ] 更新 `AGENTS.md`（编码规范文档）
- [ ] 编写 API 使用文档
- [ ] 编写测试报告
- [ ] 提交 PR 和 Code Review

**验收标准**：
- 文档完整且易懂
- Code Review 通过
- 所有测试通过

## 6. 技术决策记录

### 6.1 为什么保留本地快速匹配？

**决策**：保留硬编码关键词匹配作为第一层

**理由**：
1. **响应速度**：本地匹配 < 50ms，AI 匹配需要网络请求
2. **成本控制**：减少 AI API 调用次数
3. **可靠性**：网络故障时仍可提供基础功能
4. **渐进升级**：不破坏现有功能，平滑过渡

### 6.2 为什么使用置信度阈值 0.85？

**决策**：高置信度阈值 ≥ 0.85，低置信度 < 0.7 需确认

**理由**：
1. **用户体验**：高置信度直接执行，减少打断
2. **安全性**：低置信度请求确认，防止误操作
3. **行业实践**：语音识别和意图识别常用阈值区间

### 6.3 为什么使用分层架构？

**决策**：本地 → AI → 上下文三层架构

**理由**：
1. **性能优化**：快速路径优先
2. **成本控制**：按需调用高成本服务
3. **扩展性**：每层可独立优化和替换
4. **可测试性**：每层可独立测试

## 7. 风险与应对

### 7.1 AI 服务不稳定

**风险**：后端 AI 服务可能超时或失败

**应对**：
- 本地匹配作为 fallback
- 错误降级处理
- 重试机制（最多 3 次）

### 7.2 意图识别准确率不足

**风险**：AI 识别准确率低于预期

**应对**：
- 优化提示词工程
- 增加训练数据（用户反馈）
- 调整置信度阈值
- 用户确认机制兜底

### 7.3 多意图处理复杂

**风险**：用户输入包含多个意图，处理逻辑复杂

**应对**：
- 优先处理主要意图
- 提供选择 UI 让用户决策
- 记录多意图场景用于优化

### 7.4 性能影响

**风险**：意图识别增加响应延迟

**应对**：
- 本地匹配优先
- 异步处理不阻塞 UI
- 缓存历史识别结果
- 预加载常用意图

## 8. 测试策略

### 8.1 单元测试

**覆盖范围**：
- 模型序列化/反序列化
- 文本预处理逻辑
- 置信度计算算法
- 本地匹配关键词

**工具**：Swift Testing (`@Test`, `#expect`)

### 8.2 集成测试

**覆盖范围**：
- 服务调用流程
- ViewModel 和服务交互
- 多层意图识别融合

**工具**：Swift Testing + Mock Services

### 8.3 E2E 测试

**覆盖范围**：
- 用户输入 → 意图识别 → 导航执行
- 用户确认流程
- 错误处理流程

**工具**：手动 SmokeTests + XCUITest（可选）

### 8.4 性能测试

**指标**：
- 本地匹配响应时间
- AI 匹配响应时间
- 内存占用
- CPU 使用率

**工具**：Xcode Instruments

## 9. API 设计规范

### 9.1 意图识别请求格式

```json
{
  "text": "How can I check my balance?",
  "language": "english",
  "context": {
    "access_token": "...",
    "service_number": "...",
    "subscriber_key": "..."
  },
  "conversation_history": [
    {
      "sender": "user",
      "text": "previous message"
    }
  ],
  "options": {
    "enable_multi_intent": true,
    "confidence_threshold": 0.7
  }
}
```

### 9.2 意图识别响应格式

```json
{
  "intent_type": "balance_inquiry",
  "confidence": 0.92,
  "navigation_target": "home",
  "business_parameters": {
    "action": "view_balance"
  },
  "requires_confirmation": false,
  "suggested_actions": [
    {
      "id": "action_1",
      "title": "View Balance",
      "action_type": "navigate",
      "parameters": {
        "target": "home"
      }
    }
  ],
  "alternative_intents": [
    {
      "intent_type": "account_help",
      "confidence": 0.15,
      "description": "Account assistance"
    }
  ]
}
```

## 10. 后续优化方向

### 10.1 用户反馈闭环

- 收集用户确认/拒绝数据
- 用于优化 AI 模型
- 定期更新本地关键词列表

### 10.2 个性化意图识别

- 基于用户历史偏好
- 个性化置信度阈值
- 定制化意图分类

### 10.3 多模态输入

- 语音输入意图识别
- 图片输入意图识别（OCR + 意图）
- 手势输入意图识别

## 11. 时间估算

**总计**：11-15 天（包含测试和文档）

| 阶段 | 时间 | 关键交付物 |
|------|------|-----------|
| 模型层 | 2-3 天 | IntentModels.swift |
| 服务层 | 3-4 天 | DefaultIntentRecognitionService.swift |
| ViewModel | 2-3 天 | IntentRecognitionViewModel.swift |
| UI 层 | 1-2 天 | IntentFeedbackView.swift |
| 测试优化 | 2-3 天 | 测试报告 |
| 文档交付 | 1 天 | AGENTS.md 更新 |

## 12. 参考资料

- **现有代码**：
  - `AIChatModels.swift`：现有数据模型
  - `AIChatViewModel.swift`：现有意图识别逻辑（第 57-99 行）
  - `AIChatServicing.swift`：现有服务协议

- **编码规范**：
  - `ioscrmapp/AGENTS.md`：Swift 编码规范
  - `openspec/specs/security/`：安全规范

- **技能文档**：
  - `swift-protocol-di-testing`：协议依赖注入和测试
  - `swiftui-performance-audit`：SwiftUI 性能优化
  - `ios-debugger-agent`：iOS 调试技巧

---

**下一步行动**：
1. 用户审批此计划
2. 开始阶段 1：模型层构建
3. 创建第一个任务清单（TodoWrite）