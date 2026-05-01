import SwiftUI

// MARK: - Payment Card Color Extensions

extension Color {
    static let paymentCardBackground = Color(red: 30/255, green: 30/255, blue: 30/255)
    static let paymentAccent = Color(red: 0/255, green: 122/255, blue: 255/255)
    static let paymentGlow = Color(red: 100/255, green: 200/255, blue: 255/255)
}

// MARK: - Payment Card View

struct AIChatPaymentCardView: View {
    let paymentCard: AIChatPaymentCard
    let paymentService: PaymentServicing
    let context: PaymentContext
    let onComplete: (PaymentResultCard) -> Void

    @State private var selectedAmount: Decimal
    @State private var selectedMethodId: String
    @State private var isProcessing = false
    @State private var resultCard: PaymentResultCard?

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

        _selectedAmount = State(initialValue: paymentCard.amountOptions.defaultAmount)
        _selectedMethodId = State(initialValue: paymentCard.defaultPaymentMethod()?.id ?? "")
    }

    var body: some View {
        ZStack {
            mainContent

            if isProcessing {
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .paymentAccent))
                        .scaleEffect(1.5)

                    Text("Processing payment...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }

            if let result = resultCard {
                PaymentResultView(result: result, onDismiss: { onComplete(result) })
            }
        }
        .padding(24)
        .background(Color.paymentCardBackground.opacity(0.8))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.1), lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 25, y: 25)
    }

    private var mainContent: some View {
        VStack(spacing: 20) {
            // Amount Section
            VStack(spacing: 8) {
                Text("RECHARGE AMOUNT")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .tracking(1)

                HStack(spacing: 4) {
                    Text(formatAmount(selectedAmount))
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .paymentGlow.opacity(0.5), radius: 30)

                    Text(paymentCard.amountOptions.currency)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.gray)
                }
            }

            // Quick Amounts
            HStack(spacing: 10) {
                ForEach(paymentCard.amountOptions.quickAmounts, id: \.self) { amount in
                    Button {
                        selectedAmount = amount
                    } label: {
                        Text(formatAmount(amount))
                            .font(.system(size: 14, weight: selectedAmount == amount ? .semibold : .regular))
                            .foregroundColor(selectedAmount == amount ? .white : .gray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 12)
                                .fill(selectedAmount == amount ? .paymentAccent.opacity(0.3) : Color.gray.opacity(0.3)))
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(selectedAmount == amount ? .paymentAccent.opacity(0.4) : .white.opacity(0.05), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Payment Methods
            VStack(spacing: 10) {
                Text("PAYMENT METHOD")
                    .font(.caption2)
                    .foregroundColor(.gray.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(paymentCard.paymentMethods) { method in
                    PaymentMethodRowView(
                        method: method,
                        isSelected: selectedMethodId == method.id
                    ) {
                        selectedMethodId = method.id
                    }
                }
            }

            // Confirm Button
            Button {
                processPayment()
            } label: {
                HStack(spacing: 8) {
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }

                    Text(isProcessing ? "Processing..." : "Confirm Payment • \(formatAmount(selectedAmount)) \(paymentCard.amountOptions.currency)")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(colors: [.paymentAccent, Color(red: 86/255)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.1), lineWidth: 1))
                .shadow(color: .paymentAccent.opacity(0.4), radius: 30, y: 10)
            }
            .buttonStyle(.plain)
            .disabled(!paymentCard.amountOptions.isValidAmount(selectedAmount) || isProcessing)
        }
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: amount as NSNumber) ?? "\(amount)"
    }

    private func processPayment() {
        isProcessing = true

        Task {
            do {
                let result = try await paymentService.processPayment(
                    methodId: selectedMethodId,
                    amount: selectedAmount,
                    context: context
                )

                await MainActor.run {
                    resultCard = result
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    resultCard = PaymentResultCard(
                        status: .failed,
                        orderId: nil,
                        amount: selectedAmount,
                        currency: paymentCard.amountOptions.currency,
                        message: "Network error. Please try again.",
                        timestamp: Date()
                    )
                    isProcessing = false
                }
            }
        }
    }
}

// MARK: - Payment Method Row

struct PaymentMethodRowView: View {
    let method: PaymentMethodOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(method.iconType.emoji)
                    .font(.system(size: 20))
                    .frame(width: 48, height: 48)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(red: 26/255)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(method.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .gray.opacity(0.9))

                    Text(method.description)
                        .font(.system(size: 12))
                        .foregroundColor(isSelected ? .paymentAccent : .gray.opacity(0.6))
                }

                Spacer()

                ZStack {
                    if isSelected {
                        Circle()
                            .fill(.paymentAccent)
                            .frame(width: 24, height: 24)
                            .shadow(color: .paymentAccent.opacity(0.5), radius: 10)

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
            .background(RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ? .paymentAccent.opacity(0.15) : Color.paymentCardBackground.opacity(0.6)))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isSelected ? .paymentAccent.opacity(0.3) : .white.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Payment Result View

struct PaymentResultView: View {
    let result: PaymentResultCard
    let onDismiss: () -> Void

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

            if let orderId = result.orderId {
                Text("Order ID: \(orderId)")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.6))
            }

            Text("\(formatAmount(result.amount)) \(result.currency)")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

            Button(action: onDismiss) {
                Text(result.status == .success ? "Done" : "Retry")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(result.status == .success ? .green : .paymentAccent)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Capsule()
                        .fill(result.status == .success ? Color.green.opacity(0.2) : Color.paymentAccent.opacity(0.2)))
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .background(Color.paymentCardBackground.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: amount as NSNumber) ?? "\(amount)"
    }
}