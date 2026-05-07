import Foundation

// MARK: - Mock Offers Service (for examples)

/// Mock Offers 服务实现，用于示例和测试
private struct ExampleMockOffersService: OffersServicing {
    func fetchLanding(session: CustSubInfo) async throws -> OffersLandingSnapshot {
        throw OffersServiceError.featureUnavailable(message: "Mock service")
    }

    func fetchSubscribedOffers(session: CustSubInfo) async throws -> [SubscribedOfferItem] {
        return []
    }

    func fetchCategories(session: CustSubInfo) async throws -> [OfferCategoryItem] {
        return []
    }

    func fetchDIYBootstrap(session: CustSubInfo) async throws -> DIYOfferBootstrap {
        throw OffersServiceError.featureUnavailable(message: "Mock service")
    }

    func calculateDIYPrice(_ request: DIYOfferPricingRequest, session: CustSubInfo) async throws -> DIYOfferPricing {
        throw OffersServiceError.featureUnavailable(message: "Mock service")
    }

    func submitDIYOffer(_ request: DIYOfferSubmissionRequest, session: CustSubInfo) async throws -> OfferAcceptedResult {
        throw OffersServiceError.featureUnavailable(message: "Mock service")
    }

    func fetchOrders(session: CustSubInfo, filter: OffersOrderFilter, pageIndex: Int, pageSize: Int) async throws -> OffersOrderPageSnapshot {
        throw OffersServiceError.featureUnavailable(message: "Mock service")
    }

    func fetchEligibleOffers(session: CustSubInfo, resourceType: OffersResourceType, categoryId: String?) async throws -> [EligibleOfferItem] {
        return []
    }

    func submitChange(_ request: OfferChangeRequest, session: CustSubInfo) async throws -> OfferAcceptedResult {
        throw OffersServiceError.featureUnavailable(message: "Mock service")
    }
}

// MARK: - Integration Example: AppServices Extension

/// AppServices 扩展示例，展示如何集成意图识别服务
extension AppServices {
    /// 创建带意图识别的服务实例
    static func withIntentRecognition() -> AppServices {
        let services = AppServices()

        // 注意：需要在 AppServices 结构体中添加 intentRecognitionService 属性
        // 这里仅作为示例展示集成思路

        return services
    }
}

// MARK: - Integration Example: Enhanced AppServices

/// 增强版 AppServices（包含意图识别服务）
struct EnhancedAppServices {
    let offersService: any OffersServicing
    let aiChatService: any AIChatServicing
    let intentRecognitionService: any IntentRecognitionServicing

    init() {
        // 初始化基础服务
        offersService = ExampleMockOffersService()
        aiChatService = MockAIChatService()

        // 初始化意图识别服务（使用 Mock 实现）
        intentRecognitionService = MockIntentRecognitionService()
    }

    /// 使用真实 AI 服务初始化
    init(withRealAI: Bool) {
        offersService = ExampleMockOffersService()

        if withRealAI {
            // 使用真实 AI 服务（需要配置）
            aiChatService = RemoteAIChatService(configuration: AIChatConfiguration.current)
            intentRecognitionService = AppServices.makeIntentRecognitionService(
                aiChatService: aiChatService
            )
        } else {
            // 使用 Mock 服务（开发和测试）
            aiChatService = MockAIChatService()
            intentRecognitionService = MockIntentRecognitionService()
        }
    }
}

// MARK: - Integration Example: Intent Recognition Helper

/// 意图识别辅助工具，简化调用流程
final class IntentRecognitionHelper: Sendable {
    private let service: any IntentRecognitionServicing

    init(service: any IntentRecognitionServicing = MockIntentRecognitionService()) {
        self.service = service
    }

    /// 快速识别意图并获取导航目标
    func quickRecognize(
        text: String,
        language: AppLanguage
    ) async -> AIChatNavigationTarget? {
        // 仅使用本地匹配（快速路径）
        if let result = await service.localMatch(text: text, language: language),
           result.isHighConfidence {
            return result.navigationTarget
        }

        return nil
    }

    /// 完整意图识别流程（包含 AI 分析）
    func fullRecognize(
        text: String,
        language: AppLanguage,
        context: AIChatContext,
        history: [AIChatMessage] = []
    ) async throws -> IntentRecognitionResult {
        return try await service.recognizeIntent(
            text: text,
            context: context,
            conversationHistory: history,
            language: language
        )
    }

    /// 检查是否需要用户确认
    func needsConfirmation(_ result: IntentRecognitionResult) -> Bool {
        return result.needsUserConfirmation
    }
}

// MARK: - Integration Example: Intent Recognition Usage

/// 意图识别使用示例代码
enum IntentRecognitionUsageExample {
    /// 示例 1：简单意图识别
    static func simpleRecognitionExample() async {
        let helper = IntentRecognitionHelper()

        // 快速识别用户输入
        let target = await helper.quickRecognize(
            text: "check my balance",
            language: .english
        )

        if let target {
            print("导航到: \(target)")
        } else {
            print("无法识别意图")
        }
    }

    /// 示例 2：完整意图识别流程
    static func fullRecognitionExample() async throws {
        let helper = IntentRecognitionHelper(
            service: AppServices.makeIntentRecognitionService(
                aiChatService: MockAIChatService()
            )
        )

        // 构建上下文
        let context = AIChatContext(
            accessToken: "test_token",
            authorization: "Bearer test_token",
            userID: "user_123",
            serviceNumber: "12345678",
            subscriberKey: "sub_key",
            languageCode: "en",
            displayName: "Test User"
        )

        // 执行完整识别
        let result = try await helper.fullRecognize(
            text: "I want to recharge my account",
            language: .english,
            context: context
        )

        // 处理识别结果
        print("意图类型: \(result.intentType.displayName(for: .english))")
        print("置信度: \(result.confidence)")

        if result.needsUserConfirmation {
            print("需要用户确认")
        } else {
            print("可以直接执行")
        }
    }

    /// 示例 3：多意图场景处理
    static func multiIntentExample() async throws {
        let service = MockIntentRecognitionService()

        let context = AIChatContext(
            accessToken: "test",
            authorization: "Bearer test",
            userID: "user",
            serviceNumber: "123",
            subscriberKey: "key",
            languageCode: "en",
            displayName: "User"
        )

        // 用户输入可能包含多个意图
        let text = "I want to check my balance and then recharge"

        // 识别意图
        let result = try await service.recognizeIntent(
            text: text,
            context: context,
            conversationHistory: [],
            language: .english
        )

        // 检查是否有替代意图
        if result.hasAlternatives {
            print("检测到多个意图:")
            print("主要意图: \(result.intentType.displayName(for: .english))")

            for alternative in result.alternativeIntents {
                print("替代意图: \(alternative.intentType.displayName(for: .english)) - \(alternative.confidence)")
            }
        }
    }

    /// 示例 4：ViewModel 集成
    @MainActor
    static func viewModelIntegrationExample() {
        // 创建带意图识别的 ViewModel
        let viewModel = AIChatViewModel(
            custSubInfo: CustSubInfo.mock, // 需要 mock 数据
            language: .english,
            aiChatService: MockAIChatService(),
            intentRecognitionService: MockIntentRecognitionService()
        )

        // 使用意图识别功能
        let text = "How can I check my balance?"

        // 旧方式：硬编码匹配
        let legacyTarget = viewModel.directNavigationTarget(for: text)
        print(String(describing: legacyTarget))

        // 新方式：意图识别服务（异步）
        viewModel.processPotentialNavigation(for: text) {
            viewModel.sendMessageText(text)
        }
    }
}

// MARK: - Mock Data Helper

/// Mock 数据辅助工具，用于测试和示例
struct MockDataHelper {
    /// 创建 Mock 用户信息
    static func mockCustSubInfo() -> CustSubInfo {
        // 注意：需要根据实际 CustSubInfo 结构创建 mock
        // 这里仅作为示例占位
        return CustSubInfo.mock
    }

    /// 创建 Mock AI 上下文
    static func mockAIChatContext() -> AIChatContext {
        return AIChatContext(
            accessToken: "mock_access_token",
            authorization: "Bearer mock_access_token",
            userID: "mock_user_id",
            serviceNumber: "12345678",
            subscriberKey: "mock_subscriber_key",
            languageCode: "en",
            displayName: "Mock User"
        )
    }

    /// 创建 Mock 聊天历史
    static func mockConversationHistory() -> [AIChatMessage] {
        return [
            AIChatMessage(
                sender: .user,
                text: "Previous question about balance"
            ),
            AIChatMessage(
                sender: .assistant,
                text: "You can check your balance in the home page."
            )
        ]
    }
}

// MARK: - Usage Notes

/*
 ## 集成使用说明

 ### 1. 在 AppServices 中集成

 ```swift
 struct AppServices {
     let offersService: any OffersServicing
     let aiChatService: any AIChatServicing
     let intentRecognitionService: any IntentRecognitionServicing // 新增

     init() {
         offersService = MockOffersService()
         aiChatService = MockAIChatService()
         intentRecognitionService = DefaultIntentRecognitionService(
             aiChatService: aiChatService
         )
     }
 }
 ```

 ### 2. 在 ViewModel 中使用

 ```swift
 let viewModel = AIChatViewModel(
     custSubInfo: custSubInfo,
     language: language,
     aiChatService: AppServices().aiChatService,
     intentRecognitionService: AppServices().intentRecognitionService // 新增
 )
 ```

 ### 3. 在 View 中处理导航

 ```swift
 AIChatView(
     custSubInfo: custSubInfo,
     language: language,
     aiChatService: aiChatService,
     intentRecognitionService: intentRecognitionService, // 新增
     onNavigate: { target in
         // 处理导航
         navigateTo(target)
     }
 )
 ```

 ### 4. 直接使用意图识别 Helper

 ```swift
 let helper = IntentRecognitionHelper()

 // 快速识别
 let target = await helper.quickRecognize(text: "check balance", language: .english)

 // 完整识别
 let result = try await helper.fullRecognize(
     text: "I need help",
     language: .english,
     context: context
 )
 ```

 ### 5. 处理意图确认

 ```swift
 if result.needsUserConfirmation {
     // 显示确认对话框
     showIntentConfirmation(result: result)
 } else {
     // 直接执行导航
     navigateTo(result.navigationTarget)
 }
 ```

 ## 注意事项

 1. **依赖注入**：意图识别服务通过构造器注入，支持测试和灵活性
 2. **向后兼容**：如果 intentRecognitionService 为 nil，会 fallback 到硬编码逻辑
 3. **异步处理**：意图识别是异步操作，不阻塞 UI
 4. **置信度判断**：根据置信度决定是否需要用户确认
 5. **多语言支持**：所有意图类型支持三语言显示名称

 ## 测试建议

 - 使用 MockIntentRecognitionService 进行单元测试
 - 使用 MockAIChatService 进行集成测试
 - 使用 IntentRecognitionHelper 简化调用流程
 - 验证本地匹配命中率和响应时间
 */
