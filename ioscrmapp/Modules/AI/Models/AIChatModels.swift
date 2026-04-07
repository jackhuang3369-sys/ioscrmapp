import Foundation

enum AIChatSender: String, Equatable {
    case user
    case assistant
}

enum AIChatViewStep: Equatable {
    case home
    case offersList
    case answer
    case offerDetails(AIChatOffer)
    case success
}

enum AIChatNavigationTarget: Equatable {
    case home
    case service
    case mall
    case offers
    case billing
    case recharge
    case me
    case external(URL)
}

struct AIChatOffer: Identifiable, Equatable {
    let id: UUID
    let name: String
    let price: String
    let dataAmount: String
    let validity: String
    let currency: String
    let unit: String

    init(
        id: UUID = UUID(),
        name: String,
        price: String,
        dataAmount: String,
        validity: String,
        currency: String = "SDG",
        unit: String = "Month"
    ) {
        self.id = id
        self.name = name
        self.price = price
        self.dataAmount = dataAmount
        self.validity = validity
        self.currency = currency
        self.unit = unit
    }
}

struct AIChatAction: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let target: AIChatNavigationTarget?
    let rawValue: String?
}

struct AIChatMessage: Identifiable, Equatable {
    let id: UUID
    let sender: AIChatSender
    var text: String
    var htmlContent: String?
    var richText: AttributedString?
    var thinkingText: String
    var recommendedOffers: [AIChatOffer]
    var actions: [AIChatAction]
    let createdAt: Date
    var isLoading: Bool

    init(
        id: UUID = UUID(),
        sender: AIChatSender,
        text: String,
        thinkingText: String = "",
        recommendedOffers: [AIChatOffer] = [],
        actions: [AIChatAction] = [],
        createdAt: Date = Date(),
        isLoading: Bool = false
    ) {
        self.id = id
        self.sender = sender
        self.text = text
        htmlContent = nil
        richText = nil
        self.thinkingText = thinkingText
        self.recommendedOffers = recommendedOffers
        self.actions = actions
        self.createdAt = createdAt
        self.isLoading = isLoading
    }
}

struct AIChatContext {
    let accessToken: String
    let authorization: String
    let userID: String
    let serviceNumber: String
    let subscriberKey: String
    let languageCode: String
    let displayName: String
}

struct AIChatReply {
    let conversationID: String?
    let text: String
    let htmlContent: String?
    let richText: AttributedString?
    let thinkingText: String
    let recommendedOffers: [AIChatOffer]
    let actions: [AIChatAction]

    init(
        conversationID: String?,
        text: String,
        htmlContent: String? = nil,
        richText: AttributedString? = nil,
        thinkingText: String,
        recommendedOffers: [AIChatOffer] = [],
        actions: [AIChatAction]
    ) {
        self.conversationID = conversationID
        self.text = text
        self.htmlContent = htmlContent
        self.richText = richText
        self.thinkingText = thinkingText
        self.recommendedOffers = recommendedOffers
        self.actions = actions
    }
}

enum AIChatServiceError: Error {
    case missingConfiguration
    case invalidResponse
    case backend(String)
    case network(underlying: Error)
}

enum AIChatLocalizedCopy {
    static func title(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "How may I help\nyou today?"
        case .simplifiedChinese:
            return "我能帮你\n做什么？"
        case .arabic:
            return "كيف يمكنني\nمساعدتك اليوم؟"
        }
    }

    static func subtitle(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Ask about bills, offers, recharge, or account help."
        case .simplifiedChinese:
            return "可以咨询账单、优惠、充值和账户问题。"
        case .arabic:
            return "يمكنك السؤال عن الفواتير والعروض وإعادة الشحن والحساب."
        }
    }

    static func recommendedTitle(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Recommended Questions"
        case .simplifiedChinese:
            return "推荐问题"
        case .arabic:
            return "أسئلة مقترحة"
        }
    }

    static func inputPlaceholder(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Enter the content you want to consult"
        case .simplifiedChinese:
            return "请输入你想咨询的内容"
        case .arabic:
            return "أدخل المحتوى الذي تريد الاستفسار عنه"
        }
    }

    static func voiceHoldTitle(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Hold to Talk ~"
        case .simplifiedChinese:
            return "按住说话~"
        case .arabic:
            return "اضغط للتحدث ~"
        }
    }

    static func voiceListeningTitle(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Listening..."
        case .simplifiedChinese:
            return "正在聆听..."
        case .arabic:
            return "جارٍ الاستماع..."
        }
    }

    static func voiceEntryTitle(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Voice input"
        case .simplifiedChinese:
            return "语音输入"
        case .arabic:
            return "إدخال صوتي"
        }
    }

    static func keyboardEntryTitle(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Keyboard input"
        case .simplifiedChinese:
            return "键盘输入"
        case .arabic:
            return "إدخال لوحة المفاتيح"
        }
    }

    static func sendButtonTitle(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Send"
        case .simplifiedChinese:
            return "发送"
        case .arabic:
            return "إرسال"
        }
    }

    static func newChatTitle(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "New Chat"
        case .simplifiedChinese:
            return "新对话"
        case .arabic:
            return "محادثة جديدة"
        }
    }

    static func closeTitle(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Close"
        case .simplifiedChinese:
            return "关闭"
        case .arabic:
            return "إغلاق"
        }
    }

    static func thinkingTitle(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Thinking"
        case .simplifiedChinese:
            return "思考过程"
        case .arabic:
            return "التفكير"
        }
    }

    static func loadingTitle(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Generating reply..."
        case .simplifiedChinese:
            return "正在生成回复..."
        case .arabic:
            return "جارٍ إنشاء الرد..."
        }
    }

    static func offersResultTitle(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Here are the recommended package options for you~"
        case .simplifiedChinese:
            return "这里是为你推荐的套餐选项~"
        case .arabic:
            return "هذه هي الباقات المقترحة المناسبة لك~"
        }
    }

    static func questionSectionTitle(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Your Question"
        case .simplifiedChinese:
            return "你的问题"
        case .arabic:
            return "سؤالك"
        }
    }

    static func answerSectionTitle(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Assistant Reply"
        case .simplifiedChinese:
            return "智能体回复"
        case .arabic:
            return "رد المساعد"
        }
    }

    static func suggestedActionsTitle(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Suggested Actions"
        case .simplifiedChinese:
            return "建议操作"
        case .arabic:
            return "إجراءات مقترحة"
        }
    }

    static func continueAskingHint(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "You can continue asking questions, or choose one of the actions below."
        case .simplifiedChinese:
            return "你可以继续提问，或选择下面的操作。"
        case .arabic:
            return "يمكنك متابعة طرح الأسئلة أو اختيار أحد الإجراءات أدناه."
        }
    }

    static func emptyReply(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "I didn't receive a usable reply this time. Please try again."
        case .simplifiedChinese:
            return "这次没有拿到可用回复，请再试一次。"
        case .arabic:
            return "لم أتلقَّ ردًا صالحًا هذه المرة. حاول مرة أخرى."
        }
    }

    static func errorMessage(for language: AppLanguage, error: AIChatServiceError) -> String {
        switch error {
        case .missingConfiguration:
            switch language {
            case .english:
                return "AI assistant configuration is missing."
            case .simplifiedChinese:
                return "AI 助手配置缺失。"
            case .arabic:
                return "إعدادات المساعد الذكي غير مكتملة."
            }
        case .invalidResponse:
            switch language {
            case .english:
                return "The assistant returned an invalid response."
            case .simplifiedChinese:
                return "智能体返回了无效响应。"
            case .arabic:
                return "أعاد المساعد استجابة غير صالحة."
            }
        case let .backend(message):
            return message
        case .network:
            switch language {
            case .english:
                return "Network error. Please check your connection and try again."
            case .simplifiedChinese:
                return "网络异常，请检查连接后重试。"
            case .arabic:
                return "حدث خطأ في الشبكة. تحقق من الاتصال ثم حاول مرة أخرى."
            }
        }
    }

    static func suggestedPrompts(for language: AppLanguage) -> [String] {
        switch language {
        case .english:
            return [
                "How can I check my balance?",
                "What offers are available for me?",
                "How do I recharge my account?",
                "How can I view my bill?"
            ]
        case .simplifiedChinese:
            return [
                "我怎么查看余额？",
                "我有哪些可用优惠？",
                "我怎么给账户充值？",
                "我怎么查看账单？"
            ]
        case .arabic:
            return [
                "كيف أتحقق من الرصيد؟",
                "ما العروض المتاحة لي؟",
                "كيف أعيد شحن الحساب؟",
                "كيف أعرض الفاتورة؟"
            ]
        }
    }

    static func actionTitle(for target: AIChatNavigationTarget, language: AppLanguage) -> String {
        switch (target, language) {
        case (.billing, .english):
            return "Open Billing"
        case (.billing, .simplifiedChinese):
            return "打开账单"
        case (.billing, .arabic):
            return "فتح الفواتير"
        case (.recharge, .english):
            return "Open Recharge"
        case (.recharge, .simplifiedChinese):
            return "打开充值"
        case (.recharge, .arabic):
            return "فتح إعادة الشحن"
        case (.offers, .english):
            return "Open Offers"
        case (.offers, .simplifiedChinese):
            return "打开优惠"
        case (.offers, .arabic):
            return "فتح العروض"
        case (.mall, .english):
            return "Open Mall"
        case (.mall, .simplifiedChinese):
            return "打开商城"
        case (.mall, .arabic):
            return "فتح المتجر"
        case (.home, .english):
            return "Open Home"
        case (.home, .simplifiedChinese):
            return "打开首页"
        case (.home, .arabic):
            return "فتح الرئيسية"
        case (.service, .english):
            return "Open Service"
        case (.service, .simplifiedChinese):
            return "打开服务"
        case (.service, .arabic):
            return "فتح الخدمات"
        case (.me, .english):
            return "Open Me"
        case (.me, .simplifiedChinese):
            return "打开我的"
        case (.me, .arabic):
            return "فتح حسابي"
        case (.external, .english):
            return "Open Link"
        case (.external, .simplifiedChinese):
            return "打开链接"
        case (.external, .arabic):
            return "فتح الرابط"
        }
    }
}
