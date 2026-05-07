import SwiftUI

// MARK: - Payment Card Color Extensions

extension Color {
    static let paymentCardBackground = Color(red: 30 / 255, green: 30 / 255, blue: 30 / 255)
    static let paymentAccent = Color(red: 0 / 255, green: 122 / 255, blue: 255 / 255)
    static let paymentGlow = Color(red: 100 / 255, green: 200 / 255, blue: 255 / 255)
}

// MARK: - Payment Card View

struct AIChatPaymentCardView: View {
    let paymentCard: AIChatPaymentCard
    let paymentService: PaymentServicing
    let context: PaymentContext
    let onComplete: (PaymentResultCard) -> Void

    @State private var selectedAmount: Decimal
    @State private var selectedMethodId: String
    @State private var customAmountText: String
    @State private var otpCode = ""
    @State private var flowState: PaymentFlowState
    @State private var activeResult: PaymentResultCard?
    @State private var inlineErrorMessage: String?

    @FocusState private var isAmountFieldFocused: Bool
    @FocusState private var isOTPFieldFocused: Bool

    init(
        paymentCard: AIChatPaymentCard,
        paymentService: PaymentServicing = MockPaymentService(),
        context: PaymentContext,
        onComplete: @escaping (PaymentResultCard) -> Void
    ) {
        self.paymentCard = paymentCard
        self.paymentService = paymentService
        self.context = context
        self.onComplete = onComplete

        let initialAmount = paymentCard.amountOptions.defaultAmount
        let initialMethodId = paymentCard.defaultPaymentMethod()?.id ?? paymentCard.paymentMethods.first?.id ?? ""

        _selectedAmount = State(initialValue: initialAmount)
        _selectedMethodId = State(initialValue: initialMethodId)
        _customAmountText = State(initialValue: Self.formatAmount(initialAmount))
        _flowState = State(
            initialValue: initialMethodId.isEmpty
                ? .selectingAmount(initialAmount)
                : .selectingMethod(selectedMethodId: initialMethodId, amount: initialAmount)
        )
    }

    private var copy: PaymentCardCopy {
        PaymentCardCopy(
            languageCode: context.languageCode,
            transactionType: paymentCard.transactionType
        )
    }

    private var selectedMethod: PaymentMethodOption? {
        paymentCard.paymentMethods.first { $0.id == selectedMethodId }
    }

    private var amountIsValid: Bool {
        paymentCard.amountOptions.isValidAmount(selectedAmount)
    }

    private var amountValidationMessage: String? {
        guard !amountIsValid else {
            return nil
        }

        return copy.amountValidationMessage(
            minimum: paymentCard.amountOptions.min,
            maximum: paymentCard.amountOptions.max,
            currency: paymentCard.amountOptions.currency
        )
    }

    private var confirmButtonTitle: String {
        switch flowState {
        case .processing:
            return copy.processingTitle
        case .otpRequired:
            return copy.verifyAndPayTitle(
                amount: selectedAmount,
                currency: paymentCard.amountOptions.currency
            )
        default:
            return copy.confirmTitle(
                amount: selectedAmount,
                currency: paymentCard.amountOptions.currency
            )
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 18) {
                amountSection
                paymentMethodSection

                if let method = selectedMethod, let installmentOptions = method.installmentOptions, !installmentOptions.isEmpty {
                    installmentSection(options: installmentOptions)
                }

                if let subscriberInfo = paymentCard.subscriberInfo {
                    subscriberSection(info: subscriberInfo)
                }

                if case .otpRequired(_, _, let maskedAccount) = flowState {
                    otpSection(maskedAccount: maskedAccount)
                }

                if let error = inlineErrorMessage {
                    inlineMessage(text: error, isError: true)
                } else if let validationMessage = amountValidationMessage {
                    inlineMessage(text: validationMessage, isError: true)
                }

                confirmButton
            }
            .padding(24)

            if flowState.isProcessing {
                processingOverlay
            }

            if let result = activeResult {
                PaymentResultView(
                    result: result,
                    primaryActionTitle: result.status == .success ? copy.doneTitle : copy.retryTitle,
                    onPrimaryAction: {
                        if result.status == .success {
                            onComplete(result)
                        } else {
                            activeResult = nil
                            syncFlowState()
                        }
                    }
                )
            }
        }
        .background(Color.paymentCardBackground.opacity(0.8))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 25, y: 25)
    }

    private var amountSection: some View {
        VStack(spacing: 14) {
            VStack(spacing: 6) {
                Text(copy.amountTitle)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .tracking(1)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(Self.formatAmount(selectedAmount))
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: Color.paymentGlow.opacity(0.45), radius: 24)

                    Text(paymentCard.amountOptions.currency)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.gray)
                }
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: max(1, min(paymentCard.amountOptions.quickAmounts.count, 4))),
                spacing: 10
            ) {
                ForEach(paymentCard.amountOptions.quickAmounts, id: \.self) { amount in
                    quickAmountButton(amount: amount)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(copy.customAmountTitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.65))

                HStack(spacing: 10) {
                    Text(paymentCard.amountOptions.currency)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.78))

                    TextField(copy.customAmountPlaceholder, text: $customAmountText)
                        .keyboardType(.decimalPad)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .foregroundColor(.white)
                        .focused($isAmountFieldFocused)
                        .onChange(of: customAmountText) { value in
                            guard let amount = Self.decimalAmount(from: value) else {
                                return
                            }
                            selectedAmount = amount
                            syncFlowState(clearFeedback: true)
                        }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.black.opacity(0.18))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                )
            }
        }
    }

    private var paymentMethodSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(copy.paymentMethodTitle)
                .font(.caption2)
                .foregroundColor(.gray.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(paymentCard.paymentMethods) { method in
                PaymentMethodRowView(
                    method: method,
                    currency: paymentCard.amountOptions.currency,
                    isSelected: selectedMethodId == method.id
                ) {
                    selectedMethodId = method.id
                    syncFlowState(clearFeedback: true)
                }
            }
        }
    }

    private func installmentSection(options: [InstallmentOption]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(copy.installmentTitle)
                .font(.caption2)
                .foregroundColor(.gray.opacity(0.7))

            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                HStack {
                    Text(copy.installmentDescription(for: option.installments))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.88))

                    Spacer()

                    Text("\(Self.formatAmount(option.amountPerInstallment)) \(paymentCard.amountOptions.currency)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.paymentAccent)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.paymentAccent.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.paymentAccent.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }

    private func subscriberSection(info: PaymentSubscriberInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(copy.subscriberInfoTitle)
                .font(.caption2)
                .foregroundColor(.gray.opacity(0.7))

            VStack(alignment: .leading, spacing: 6) {
                infoRow(title: copy.serviceNumberTitle, value: info.serviceNumber)
                if let currentBalance = info.currentBalance, !currentBalance.isEmpty {
                    infoRow(title: copy.currentBalanceTitle, value: currentBalance)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
            )
        }
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.65))

            Spacer()

            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
        }
    }

    private func otpSection(maskedAccount: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(copy.otpTitle)
                .font(.caption2)
                .foregroundColor(.gray.opacity(0.7))

            Text(copy.otpDescription(maskedAccount: maskedAccount))
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.72))

            TextField(copy.otpPlaceholder, text: $otpCode)
                .keyboardType(.numberPad)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .foregroundColor(.white)
                .focused($isOTPFieldFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.black.opacity(0.18))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.paymentAccent.opacity(0.28), lineWidth: 1)
                )
        }
    }

    private func inlineMessage(text: String, isError: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(isError ? .red.opacity(0.92) : .green.opacity(0.92))

            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.88))
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isError ? Color.red.opacity(0.14) : Color.green.opacity(0.14))
        )
    }

    private var confirmButton: some View {
        Button {
            handlePrimaryAction()
        } label: {
            HStack(spacing: 8) {
                if flowState.isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }

                Text(confirmButtonTitle)
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color.paymentAccent, Color(red: 0 / 255, green: 86 / 255, blue: 179 / 255)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.paymentAccent.opacity(0.35), radius: 22, y: 10)
        }
        .buttonStyle(.plain)
        .disabled(flowState.isProcessing)
    }

    private var processingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .paymentAccent))
                .scaleEffect(1.4)

            Text(copy.processingSubtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.82))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func quickAmountButton(amount: Decimal) -> some View {
        Button {
            selectedAmount = amount
            customAmountText = Self.formatAmount(amount)
            syncFlowState(clearFeedback: true)
        } label: {
            Text(Self.formatAmount(amount))
                .font(.system(size: 14, weight: selectedAmount == amount ? .semibold : .regular))
                .foregroundColor(selectedAmount == amount ? .white : .gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(selectedAmount == amount ? Color.paymentAccent.opacity(0.28) : Color.gray.opacity(0.24))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            selectedAmount == amount ? Color.paymentAccent.opacity(0.42) : .white.opacity(0.05),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func handlePrimaryAction() {
        guard let method = selectedMethod else {
            inlineErrorMessage = copy.paymentMethodMissingMessage
            return
        }

        guard amountIsValid else {
            inlineErrorMessage = amountValidationMessage
            return
        }

        inlineErrorMessage = nil

        switch flowState {
        case .otpRequired:
            guard Self.isValidOTP(otpCode) else {
                inlineErrorMessage = copy.invalidOTPMessage
                return
            }
            processPayment(methodId: method.id, amount: selectedAmount)
        default:
            if method.requiresOTPFlow {
                requestOTP(for: method.id, amount: selectedAmount)
            } else {
                processPayment(methodId: method.id, amount: selectedAmount)
            }
        }
    }

    private func requestOTP(for methodId: String, amount: Decimal) {
        flowState = .processing(methodId: methodId, amount: amount)
        activeResult = nil

        Task {
            do {
                let maskedAccount = try await paymentService.requestOTP(
                    methodId: methodId,
                    context: context
                )

                await MainActor.run {
                    otpCode = ""
                    flowState = .otpRequired(
                        methodId: methodId,
                        amount: amount,
                        maskedAccount: maskedAccount
                    )
                    isOTPFieldFocused = true
                }
            } catch {
                await MainActor.run {
                    presentFailure(message: copy.otpRequestFailedMessage)
                }
            }
        }
    }

    private func processPayment(methodId: String, amount: Decimal) {
        flowState = .processing(methodId: methodId, amount: amount)
        activeResult = nil

        Task {
            do {
                let result = try await paymentService.processPayment(
                    methodId: methodId,
                    amount: amount,
                    context: context
                )

                await MainActor.run {
                    if result.status == .success {
                        activeResult = result
                        flowState = .success(orderId: result.orderId ?? "", amount: amount)
                    } else {
                        presentFailure(result: result)
                    }
                }
            } catch {
                await MainActor.run {
                    let failedResult = PaymentResultCard(
                        status: .failed,
                        orderId: nil,
                        amount: amount,
                        currency: paymentCard.amountOptions.currency,
                        message: copy.networkFailureMessage,
                        timestamp: Date()
                    )
                    presentFailure(result: failedResult)
                }
            }
        }
    }

    private func presentFailure(message: String) {
        let failedResult = PaymentResultCard(
            status: .failed,
            orderId: nil,
            amount: selectedAmount,
            currency: paymentCard.amountOptions.currency,
            message: message,
            timestamp: Date()
        )
        presentFailure(result: failedResult)
    }

    private func presentFailure(result: PaymentResultCard) {
        activeResult = result
        inlineErrorMessage = result.message
        flowState = .failed(errorMessage: result.message, amount: result.amount)
    }

    private func syncFlowState(clearFeedback: Bool = false) {
        if clearFeedback {
            activeResult = nil
            inlineErrorMessage = nil
            otpCode = ""
        }

        if selectedMethodId.isEmpty {
            flowState = .selectingAmount(selectedAmount)
        } else {
            flowState = .selectingMethod(selectedMethodId: selectedMethodId, amount: selectedAmount)
        }
    }

    private static func decimalAmount(from text: String) -> Decimal? {
        let sanitized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")

        guard !sanitized.isEmpty else {
            return nil
        }

        return Decimal(string: sanitized)
    }

    private static func isValidOTP(_ text: String) -> Bool {
        let digits = text.filter(\.isNumber)
        return digits.count >= 4
    }

    fileprivate static func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.minimumIntegerDigits = 1
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
    }
}

// MARK: - Payment Method Row

private struct PaymentMethodRowView: View {
    let method: PaymentMethodOption
    let currency: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(method.iconType.emoji)
                    .font(.system(size: 20))
                    .frame(width: 48, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255))
                    )

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(method.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(isSelected ? .white : .gray.opacity(0.92))

                        if method.requiresOTPFlow {
                            Text("OTP")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.paymentAccent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(Color.paymentAccent.opacity(0.16))
                                )
                        }
                    }

                    Text(method.description)
                        .font(.system(size: 12))
                        .foregroundColor(isSelected ? Color.paymentAccent : .gray.opacity(0.6))

                    if let installmentOption = method.primaryInstallmentOption {
                        Text("\(installmentOption.installments)x \(AIChatPaymentCardView.formatAmount(installmentOption.amountPerInstallment)) \(currency)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.62))
                    }
                }

                Spacer()

                ZStack {
                    if isSelected {
                        Circle()
                            .fill(Color.paymentAccent)
                            .frame(width: 24, height: 24)
                            .shadow(color: Color.paymentAccent.opacity(0.5), radius: 10)

                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Circle()
                            .strokeBorder(.white.opacity(0.1), lineWidth: 2)
                            .frame(width: 24, height: 24)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.paymentAccent.opacity(0.15) : Color.paymentCardBackground.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? Color.paymentAccent.opacity(0.3) : .white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Payment Result View

private struct PaymentResultView: View {
    let result: PaymentResultCard
    let primaryActionTitle: String
    let onPrimaryAction: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(result.status == .success ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                    .frame(width: 80, height: 80)

                Image(systemName: result.status == .success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(result.status == .success ? .green : .red)
            }

            Text(result.message)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            if let orderId = result.orderId, !orderId.isEmpty {
                Text("Order ID: \(orderId)")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.72))
            }

            Text("\(AIChatPaymentCardView.formatAmount(result.amount)) \(result.currency)")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

            Button(action: onPrimaryAction) {
                Text(primaryActionTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(result.status == .success ? .green : .paymentAccent)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(result.status == .success ? Color.green.opacity(0.18) : Color.paymentAccent.opacity(0.18))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.paymentCardBackground.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
        .padding(16)
    }
}

// MARK: - Copy Helpers

private struct PaymentCardCopy {
    let languageCode: String
    let transactionType: PaymentTransactionType

    var amountTitle: String {
        switch languageCode {
        case "zh-Hans":
            return transactionType == .subscription ? "订购金额" : "充值金额"
        case "ar":
            return transactionType == .subscription ? "مبلغ الاشتراك" : "مبلغ إعادة الشحن"
        default:
            return transactionType == .subscription ? "SUBSCRIPTION AMOUNT" : "RECHARGE AMOUNT"
        }
    }

    var customAmountTitle: String {
        switch languageCode {
        case "zh-Hans":
            return "自定义金额"
        case "ar":
            return "مبلغ مخصص"
        default:
            return "CUSTOM AMOUNT"
        }
    }

    var customAmountPlaceholder: String {
        switch languageCode {
        case "zh-Hans":
            return "输入金额"
        case "ar":
            return "أدخل المبلغ"
        default:
            return "Enter amount"
        }
    }

    var paymentMethodTitle: String {
        switch languageCode {
        case "zh-Hans":
            return "支付方式"
        case "ar":
            return "طريقة الدفع"
        default:
            return "PAYMENT METHOD"
        }
    }

    var installmentTitle: String {
        switch languageCode {
        case "zh-Hans":
            return "分期方案"
        case "ar":
            return "خطة التقسيط"
        default:
            return "INSTALLMENT PLAN"
        }
    }

    var subscriberInfoTitle: String {
        switch languageCode {
        case "zh-Hans":
            return "订户信息"
        case "ar":
            return "معلومات المشترك"
        default:
            return "SUBSCRIBER INFO"
        }
    }

    var serviceNumberTitle: String {
        switch languageCode {
        case "zh-Hans":
            return "号码"
        case "ar":
            return "رقم الخدمة"
        default:
            return "Service Number"
        }
    }

    var currentBalanceTitle: String {
        switch languageCode {
        case "zh-Hans":
            return "当前余额"
        case "ar":
            return "الرصيد الحالي"
        default:
            return "Current Balance"
        }
    }

    var otpTitle: String {
        switch languageCode {
        case "zh-Hans":
            return "验证码确认"
        case "ar":
            return "تأكيد رمز OTP"
        default:
            return "OTP VERIFICATION"
        }
    }

    func otpDescription(maskedAccount: String) -> String {
        switch languageCode {
        case "zh-Hans":
            return "我们已向 \(maskedAccount) 发送验证码。请输入验证码以继续支付。"
        case "ar":
            return "أرسلنا رمز التحقق إلى \(maskedAccount). أدخله لإكمال الدفع."
        default:
            return "We sent a one-time code to \(maskedAccount). Enter it to continue."
        }
    }

    var otpPlaceholder: String {
        switch languageCode {
        case "zh-Hans":
            return "输入 OTP"
        case "ar":
            return "أدخل OTP"
        default:
            return "Enter OTP"
        }
    }

    var processingTitle: String {
        switch languageCode {
        case "zh-Hans":
            return "处理中..."
        case "ar":
            return "جارٍ المعالجة..."
        default:
            return "Processing..."
        }
    }

    var processingSubtitle: String {
        switch languageCode {
        case "zh-Hans":
            return "正在与支付网关确认，请稍候。"
        case "ar":
            return "جارٍ تأكيد العملية مع بوابة الدفع."
        default:
            return "Confirming with the payment gateway..."
        }
    }

    func confirmTitle(amount: Decimal, currency: String) -> String {
        let amountText = AIChatPaymentCardView.formatAmount(amount)
        switch languageCode {
        case "zh-Hans":
            return "确认支付 • \(amountText) \(currency)"
        case "ar":
            return "تأكيد الدفع • \(amountText) \(currency)"
        default:
            return "Confirm Payment • \(amountText) \(currency)"
        }
    }

    func verifyAndPayTitle(amount: Decimal, currency: String) -> String {
        let amountText = AIChatPaymentCardView.formatAmount(amount)
        switch languageCode {
        case "zh-Hans":
            return "验证并支付 • \(amountText) \(currency)"
        case "ar":
            return "تحقق وادفع • \(amountText) \(currency)"
        default:
            return "Verify & Pay • \(amountText) \(currency)"
        }
    }

    var doneTitle: String {
        switch languageCode {
        case "zh-Hans":
            return "完成"
        case "ar":
            return "تم"
        default:
            return "Done"
        }
    }

    var retryTitle: String {
        switch languageCode {
        case "zh-Hans":
            return "重试"
        case "ar":
            return "إعادة المحاولة"
        default:
            return "Retry"
        }
    }

    var paymentMethodMissingMessage: String {
        switch languageCode {
        case "zh-Hans":
            return "请选择支付方式。"
        case "ar":
            return "اختر طريقة الدفع أولاً."
        default:
            return "Select a payment method first."
        }
    }

    var invalidOTPMessage: String {
        switch languageCode {
        case "zh-Hans":
            return "请输入有效的 OTP。"
        case "ar":
            return "أدخل رمز OTP صالحًا."
        default:
            return "Enter a valid OTP."
        }
    }

    var otpRequestFailedMessage: String {
        switch languageCode {
        case "zh-Hans":
            return "验证码发送失败，请稍后重试。"
        case "ar":
            return "تعذر إرسال رمز OTP. حاول مرة أخرى."
        default:
            return "Couldn't send the OTP. Please try again."
        }
    }

    var networkFailureMessage: String {
        switch languageCode {
        case "zh-Hans":
            return "网络异常，请稍后重试。"
        case "ar":
            return "حدث خطأ في الشبكة. حاول مرة أخرى."
        default:
            return "Network error. Please try again."
        }
    }

    func amountValidationMessage(minimum: Decimal, maximum: Decimal, currency: String) -> String {
        let minimumText = AIChatPaymentCardView.formatAmount(minimum)
        let maximumText = AIChatPaymentCardView.formatAmount(maximum)
        switch languageCode {
        case "zh-Hans":
            return "金额需在 \(minimumText) 到 \(maximumText) \(currency) 之间。"
        case "ar":
            return "يجب أن يكون المبلغ بين \(minimumText) و \(maximumText) \(currency)."
        default:
            return "Amount must be between \(minimumText) and \(maximumText) \(currency)."
        }
    }

    func installmentDescription(for count: Int) -> String {
        switch languageCode {
        case "zh-Hans":
            return "\(count) 期免息"
        case "ar":
            return "\(count) دفعات بدون فائدة"
        default:
            return "\(count) installments, no interest"
        }
    }
}

// MARK: - Payment Method Helpers

private extension PaymentMethodOption {
    var requiresOTPFlow: Bool {
        let normalizedID = id.lowercased()
        return normalizedID.contains("tabby") || normalizedID.contains("bnpl")
    }

    var primaryInstallmentOption: InstallmentOption? {
        installmentOptions?.first
    }
}
