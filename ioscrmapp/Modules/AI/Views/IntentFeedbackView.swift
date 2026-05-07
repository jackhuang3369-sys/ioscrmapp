import SwiftUI

// MARK: - Intent Feedback View

/// 意图确认对话框视图，用于低置信度意图的用户确认
struct IntentFeedbackView: View {
    let intentResult: IntentRecognitionResult
    let language: AppLanguage
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // 标题
            titleSection

            // 意图信息
            intentInfoSection

            // 替代意图选项（如果有）
            if intentResult.hasAlternatives {
                alternativesSection
            }

            // 确认/取消按钮
            actionButtons
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(radius: 10)
        )
        .frame(maxWidth: 320)
    }

    private var titleSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.blue)

            Text(localizedTitle)
                .font(.headline)
                .multilineTextAlignment(.center)
        }
    }

    private var intentInfoSection: some View {
        VStack(spacing: 12) {
            // 意图类型显示
            HStack {
                Text(localizedIntentLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(intentResult.intentType.displayName(for: language))
                    .font(.body)
                    .fontWeight(.medium)
            }

            // 置信度显示
            HStack {
                Text(localizedConfidenceLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("\(Int(intentResult.confidence * 100))%")
                    .font(.body)
                    .fontWeight(.medium)

                confidenceIndicator
            }
        }
    }

    private var confidenceIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(index < confidenceLevel ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }

    private var confidenceLevel: Int {
        Int(intentResult.confidence * 5)
    }

    private var alternativesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localizedAlternativesLabel)
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(intentResult.alternativeIntents.filter { $0.isSignificant }, id: \.intentType) { alternative in
                HStack {
                    Text(alternative.intentType.displayName(for: language))
                        .font(.body)

                    Text("\(Int(alternative.confidence * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: onDismiss) {
                Text(localizedDismissButton)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.gray.opacity(0.1))
                    .foregroundColor(.primary)
                    .cornerRadius(8)
            }

            Button(action: onConfirm) {
                Text(localizedConfirmButton)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
    }

    // MARK: - Localization

    private var localizedTitle: String {
        switch language {
        case .english:
            return "Did you mean?"
        case .simplifiedChinese:
            return "您的意图是？"
        case .arabic:
            return "هل قصدت؟"
        }
    }

    private var localizedIntentLabel: String {
        switch language {
        case .english:
            return "Detected Intent:"
        case .simplifiedChinese:
            return "检测到意图："
        case .arabic:
            return "القصد المكتشف:"
        }
    }

    private var localizedConfidenceLabel: String {
        switch language {
        case .english:
            return "Confidence:"
        case .simplifiedChinese:
            return "置信度："
        case .arabic:
            return "الثقة:"
        }
    }

    private var localizedAlternativesLabel: String {
        switch language {
        case .english:
            return "Other possibilities:"
        case .simplifiedChinese:
            return "其他可能性："
        case .arabic:
            return "احتمالات أخرى:"
        }
    }

    private var localizedDismissButton: String {
        switch language {
        case .english:
            return "No"
        case .simplifiedChinese:
            return "不是"
        case .arabic:
            return "لا"
        }
    }

    private var localizedConfirmButton: String {
        switch language {
        case .english:
            return "Yes"
        case .simplifiedChinese:
            return "是的"
        case .arabic:
            return "نعم"
        }
    }
}

// MARK: - Intent Confirmation Modifier

/// 意图确认对话框修饰符，用于在视图中显示确认对话框
struct IntentConfirmationModifier: ViewModifier {
    @Binding var isPresented: Bool
    let intentResult: IntentRecognitionResult?
    let language: AppLanguage
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    func body(content: Content) -> some View {
        content
            .overlay {
                if isPresented, let result = intentResult {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                            .onTapGesture {
                                onDismiss()
                            }

                        IntentFeedbackView(
                            intentResult: result,
                            language: language,
                            onConfirm: {
                                onConfirm()
                                isPresented = false
                            },
                            onDismiss: {
                                onDismiss()
                                isPresented = false
                            }
                        )
                        .environment(\.layoutDirection, language.layoutDirection)
                    }
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.25), value: isPresented)
                }
            }
    }
}

extension View {
    /// 显示意图确认对话框
    func intentConfirmation(
        isPresented: Binding<Bool>,
        intentResult: IntentRecognitionResult?,
        language: AppLanguage,
        onConfirm: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) -> some View {
        modifier(
            IntentConfirmationModifier(
                isPresented: isPresented,
                intentResult: intentResult,
                language: language,
                onConfirm: onConfirm,
                onDismiss: onDismiss
            )
        )
    }
}

// MARK: - Preview

struct IntentFeedbackView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            IntentFeedbackView(
                intentResult: IntentRecognitionResult(
                    intentType: .balanceInquiry,
                    confidence: 0.65,
                    navigationTarget: .home,
                    requiresConfirmation: true,
                    alternativeIntents: [
                        AlternativeIntent(intentType: .accountHelp, confidence: 0.25)
                    ]
                ),
                language: .english,
                onConfirm: {},
                onDismiss: {}
            )
            .previewDisplayName("Intent Feedback View - English")

            IntentFeedbackView(
                intentResult: IntentRecognitionResult(
                    intentType: .rechargeAccount,
                    confidence: 0.72,
                    navigationTarget: .recharge,
                    requiresConfirmation: true
                ),
                language: .simplifiedChinese,
                onConfirm: {},
                onDismiss: {}
            )
            .previewDisplayName("Intent Feedback View - Chinese")

            IntentFeedbackView(
                intentResult: IntentRecognitionResult(
                    intentType: .viewOffers,
                    confidence: 0.58,
                    navigationTarget: .offers,
                    requiresConfirmation: true,
                    alternativeIntents: [
                        AlternativeIntent(intentType: .subscribeOffer, confidence: 0.35)
                    ]
                ),
                language: .arabic,
                onConfirm: {},
                onDismiss: {}
            )
            .environment(\.layoutDirection, .rightToLeft)
            .previewDisplayName("Intent Feedback View - Arabic")
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
