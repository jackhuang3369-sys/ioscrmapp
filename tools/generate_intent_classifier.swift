import Foundation
import CreateML

struct IntentTrainingSample {
    let text: String
    let label: String
}

let samples: [IntentTrainingSample] = [
    .init(text: "check my balance", label: "balance_inquiry"),
    .init(text: "what is my current balance", label: "balance_inquiry"),
    .init(text: "show my remaining balance", label: "balance_inquiry"),
    .init(text: "查看余额", label: "balance_inquiry"),
    .init(text: "我的余额还有多少", label: "balance_inquiry"),
    .init(text: "الرصيد", label: "balance_inquiry"),

    .init(text: "recharge my account", label: "recharge_account"),
    .init(text: "top up my number", label: "recharge_account"),
    .init(text: "add balance to my account", label: "recharge_account"),
    .init(text: "充值", label: "recharge_account"),
    .init(text: "给我的号码充值", label: "recharge_account"),
    .init(text: "شحن الحساب", label: "recharge_account"),

    .init(text: "show me offers", label: "view_offers"),
    .init(text: "buy more data", label: "view_offers"),
    .init(text: "my data is not enough", label: "view_offers"),
    .init(text: "need more data", label: "view_offers"),
    .init(text: "查看优惠", label: "view_offers"),
    .init(text: "العروض", label: "view_offers"),

    .init(text: "subscribe this package", label: "subscribe_offer"),
    .init(text: "activate this offer", label: "subscribe_offer"),
    .init(text: "purchase that plan", label: "subscribe_offer"),
    .init(text: "订购这个套餐", label: "subscribe_offer"),
    .init(text: "激活这个流量包", label: "subscribe_offer"),
    .init(text: "اشتراك عرض", label: "subscribe_offer"),

    .init(text: "view my bill", label: "view_bill"),
    .init(text: "show my billing statement", label: "view_bill"),
    .init(text: "check invoice details", label: "view_bill"),
    .init(text: "查看账单", label: "view_bill"),
    .init(text: "我的月账单", label: "view_bill"),
    .init(text: "عرض الفاتورة", label: "view_bill"),

    .init(text: "I need account help", label: "account_help"),
    .init(text: "help with my profile", label: "account_help"),
    .init(text: "service support", label: "account_help"),
    .init(text: "账户帮助", label: "account_help"),
    .init(text: "个人账户支持", label: "account_help"),
    .init(text: "مساعدة الحساب", label: "account_help"),

    .init(text: "pay my bill", label: "make_payment"),
    .init(text: "make a payment", label: "make_payment"),
    .init(text: "settle the outstanding amount", label: "make_payment"),
    .init(text: "支付账单", label: "make_payment"),
    .init(text: "现在付款", label: "make_payment"),
    .init(text: "إجراء الدفع", label: "make_payment"),

    .init(text: "show my payment history", label: "payment_history"),
    .init(text: "past payment records", label: "payment_history"),
    .init(text: "transaction history", label: "payment_history"),
    .init(text: "支付历史", label: "payment_history"),
    .init(text: "历史付款记录", label: "payment_history"),
    .init(text: "تاريخ الدفع", label: "payment_history"),

    .init(text: "payment status", label: "payment_status"),
    .init(text: "did my payment go through", label: "payment_status"),
    .init(text: "track this payment", label: "payment_status"),
    .init(text: "支付状态", label: "payment_status"),
    .init(text: "付款成功了吗", label: "payment_status"),
    .init(text: "حالة الدفع", label: "payment_status"),

    .init(text: "I want to travel to hong kong", label: "itinerary_query"),
    .init(text: "I want to tranval to hongkong", label: "itinerary_query"),
    .init(text: "help me get a ticket to Dubai", label: "itinerary_query"),
    .init(text: "我想去香港旅行", label: "itinerary_query"),
    .init(text: "帮我订票去迪拜", label: "itinerary_query"),
    .init(text: "أريد السفر إلى هونغ كونغ", label: "itinerary_query"),

    .init(text: "flight tickets to hong kong", label: "flight_info"),
    .init(text: "book a flight to Dubai", label: "flight_info"),
    .init(text: "flight information for my trip", label: "flight_info"),
    .init(text: "机票信息", label: "flight_info"),
    .init(text: "订去迪拜的航班", label: "flight_info"),
    .init(text: "تذاكر طيران إلى دبي", label: "flight_info"),

    .init(text: "book a hotel in abu dhabi", label: "hotel_info"),
    .init(text: "hotel booking for hong kong", label: "hotel_info"),
    .init(text: "show hotel options", label: "hotel_info"),
    .init(text: "酒店预订", label: "hotel_info"),
    .init(text: "帮我订酒店", label: "hotel_info"),
    .init(text: "حجز فندق", label: "hotel_info"),

    .init(text: "how are you", label: "general_question"),
    .init(text: "tell me more", label: "general_question"),
    .init(text: "what can you do", label: "general_question"),
    .init(text: "你能做什么", label: "general_question"),
    .init(text: "给我介绍一下", label: "general_question"),
    .init(text: "ماذا يمكنك أن تفعل", label: "general_question"),

    .init(text: "open offers page", label: "navigation_intent"),
    .init(text: "go to billing page", label: "navigation_intent"),
    .init(text: "open recharge page", label: "navigation_intent"),
    .init(text: "打开优惠页面", label: "navigation_intent"),
    .init(text: "进入账单页", label: "navigation_intent"),
    .init(text: "افتح صفحة العروض", label: "navigation_intent"),

    .init(text: "asdfgh qwerty", label: "unknown"),
    .init(text: "123456 ???", label: "unknown"),
    .init(text: "random noise text", label: "unknown"),
    .init(text: "无意义内容", label: "unknown"),
    .init(text: "!!!", label: "unknown"),
    .init(text: "نص غير مفهوم", label: "unknown")
]

let outputPath: String
if CommandLine.arguments.count > 1 {
    outputPath = CommandLine.arguments[1]
} else {
    outputPath = "/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp/ML/IntentClassifier.mlmodel"
}

let texts = samples.map(\.text)
let labels = samples.map(\.label)
let table = try MLDataTable(dictionary: ["text": texts, "label": labels])
let classifier = try MLTextClassifier(
    trainingData: table,
    textColumn: "text",
    labelColumn: "label"
)

let outputURL = URL(fileURLWithPath: outputPath)
try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

try classifier.write(to: outputURL)
print(outputURL.path)
