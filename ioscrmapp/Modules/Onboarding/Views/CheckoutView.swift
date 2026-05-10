import SwiftUI

/// 结账页：展示订单摘要、定价明细、支付方式选择和协议同意。
/// T&C toggle 未勾选时支付按钮处于禁用状态（与 HTML 设计一致）。
struct CheckoutView: View {
    let summary: CheckoutSummary
    let onBack: () -> Void
    let onPay: () -> Void

    @State private var tcAccepted = false
    @State private var marketingAccepted = false
    // 默认选中 Apple Pay，左右滑动切换 Tabby / du Pay
    @State private var selectedPaymentMethod: CheckoutPaymentMethod = .applePay

    // Checkout 页沿用 iOS 原生深色卡片风格，与 HTML 设计保持一致
    private let cardSurface = Color(hex: 0x1C1C1E)
    private let borderSubtle = Color(hex: 0x38383A)
    private let textSecondary = Color(hex: 0x8E8E93)
    private let linkBlue = Color(hex: 0x0A84FF)
    private let rbRed = Color(hex: 0xE10600)
    private let successGreen = Color(hex: 0x34C759)

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Color.black.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // 头部沿用 onboarding 风格：左 back + 右 RedBullLogo
                        CheckoutHeader(safeTop: proxy.safeAreaInsets.top, onBack: onBack)
                        cardsContent
                        // 为底部固定 footer 预留空间
                        Color.clear.frame(height: max(proxy.safeAreaInsets.bottom, 16) + 110)
                    }
                }

                stickyFooter(safeBottom: proxy.safeAreaInsets.bottom)
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Cards

    private var cardsContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Order Summary")
            orderSummaryCard
            pricingCard

            sectionLabel("Payment Method")
            // 支付方式滑动卡片：横向 paging carousel，左右切换有动画过渡
            PaymentMethodCarousel(selectedMethod: $selectedPaymentMethod)
                .padding(.bottom, 16)

            sectionLabel("Agreements")
            agreementsCard
        }
        .padding(.horizontal, 20)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(textSecondary)
            .kerning(0.5)
            .padding(.leading, 12)
            .padding(.top, 24)
            .padding(.bottom, 8)
    }

    // MARK: Order Summary Card

    private var orderSummaryCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 0) {
                HStack(spacing: 8) {
                    Text(summary.planTitle)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    Text("eSIM")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }

                Spacer()

                // 套餐编辑在后续阶段接入，当前仅展示占位入口
                Button("Edit") {}
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(linkBlue)
            }

            Text(summary.msisdn)
                .font(.system(size: 16).monospaced())
                .foregroundColor(textSecondary)
                .padding(.top, 4)

            cardDivider

            CheckoutFeatureRow(
                icon: "chart.bar.fill",
                title: "\(summary.dataText) Data",
                subtitle: "High-speed 5G network",
                textSecondary: textSecondary
            )
            CheckoutFeatureRow(
                icon: "phone.fill",
                title: "\(summary.voiceText) Flexi Minutes",
                subtitle: "Local & International",
                textSecondary: textSecondary
            )
            .padding(.top, 12)
        }
        .padding(16)
        .background(cardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.bottom, 16)
    }

    // MARK: Pricing Card

    private var pricingCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            CheckoutPricingRow(
                label: "Base Plan (Pre-tax)",
                value: "AED \(summary.formattedBasePriceAED)",
                isTotal: false,
                textSecondary: textSecondary
            )
            .padding(.bottom, 12)

            CheckoutPricingRow(
                label: "VAT (\(Int(summary.vatRate * 100))%)",
                value: "AED \(summary.formattedVATAmountAED)",
                isTotal: false,
                textSecondary: textSecondary
            )

            cardDivider

            CheckoutPricingRow(
                label: "Total \(summary.billingPeriod) Due",
                value: "AED \(summary.formattedTotalAED)",
                isTotal: true,
                textSecondary: textSecondary
            )

            // 自动续费提示，让用户了解扣款周期
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(textSecondary)

                (Text("Plan ")
                 + Text("renews automatically").fontWeight(.semibold).foregroundColor(.white)
                 + Text(" every 30 days. You can cancel anytime in settings."))
                    .font(.system(size: 13))
                    .foregroundColor(textSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.top, 16)
        }
        .padding(16)
        .background(cardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.bottom, 16)
    }

    // MARK: Agreements Card

    private var agreementsCard: some View {
        VStack(spacing: 0) {
            // T&C toggle：必选，控制支付按钮可用状态
            HStack(alignment: .center, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Terms & Conditions")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    Text("I accept the Service Agreement and Privacy Policy.")
                        .font(.system(size: 13))
                        .foregroundColor(textSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 16)
                Toggle("", isOn: $tcAccepted)
                    .labelsHidden()
                    .tint(successGreen)  // 绿色增强安全感（HTML 注释说明）
            }
            .padding(.vertical, 6)

            cardDivider

            // 营销 toggle：可选，不影响支付按钮
            HStack(alignment: .center, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Exclusive Offers")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    Text("Send me personalized rewards and Red Bull event invites.")
                        .font(.system(size: 13))
                        .foregroundColor(textSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 16)
                Toggle("", isOn: $marketingAccepted)
                    .labelsHidden()
                    .tint(successGreen)
            }
            .padding(.vertical, 6)
        }
        .padding(16)
        .background(cardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: Sticky Footer

    private func stickyFooter(safeBottom: CGFloat) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11))
                Text("Encrypted checkout · \(selectedPaymentMethod.displayName)")
                    .font(.system(size: 12))
            }
            .foregroundColor(textSecondary)

            Button {
                // T&C 未同意时按钮禁用；正常流程通过 disabled 控制，此处为防御性校验
                guard tcAccepted else { return }
                onPay()
            } label: {
                Text("Pay AED \(summary.formattedTotalAED)")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(tcAccepted ? .white : textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        tcAccepted ? rbRed : borderSubtle,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!tcAccepted)
            .animation(.easeInOut(duration: 0.2), value: tcAccepted)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, max(safeBottom, 16))
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .fill(borderSubtle)
                .frame(height: 1),
            alignment: .top
        )
    }

    // MARK: Helpers

    private var cardDivider: some View {
        Rectangle()
            .fill(borderSubtle)
            .frame(height: 1)
            .padding(.vertical, 16)
    }
}

// MARK: - Header

/// 与 OnboardingFlowHeader 风格一致：左 back 按钮 + 右 RedBullLogo。
private struct CheckoutHeader: View {
    let safeTop: CGFloat
    let onBack: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Spacer()

            Image("RedBullLogo")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: 164, height: 32, alignment: .trailing)
                .shadow(color: Color.white.opacity(0.16), radius: 14, x: 0, y: 0)
        }
        .padding(.top, safeTop + 8)
        .padding(.horizontal, 26)
    }
}

// MARK: - Payment Method Carousel

/// 支付方式枚举：决定卡片渲染顺序、品牌色和 logo。
enum CheckoutPaymentMethod: Int, CaseIterable, Identifiable {
    case applePay
    case tabby
    case duPay

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .applePay: return "Apple Pay"
        case .tabby:    return "Tabby"
        case .duPay:    return "du Pay"
        }
    }
}

/// 横向滑动支付方式选择器：使用 TabView page style，左右滑动切换。
private struct PaymentMethodCarousel: View {
    @Binding var selectedMethod: CheckoutPaymentMethod

    var body: some View {
        VStack(spacing: 12) {
            TabView(selection: $selectedMethod) {
                ForEach(CheckoutPaymentMethod.allCases) { method in
                    PaymentMethodCard(method: method)
                        .padding(.horizontal, 4)
                        .tag(method)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 160)
            .animation(.easeInOut(duration: 0.25), value: selectedMethod)

            // 自定义 page indicator：选中点更长更亮，与套餐卡片风格统一
            HStack(spacing: 8) {
                ForEach(CheckoutPaymentMethod.allCases) { method in
                    Capsule()
                        .fill(method == selectedMethod ? Color.white : Color.white.opacity(0.28))
                        .frame(width: method == selectedMethod ? 22 : 6, height: 6)
                        .animation(.easeInOut(duration: 0.2), value: selectedMethod)
                }
            }
        }
    }
}

/// 单张支付方式卡片：背景品牌色 + 中央 logo。
private struct PaymentMethodCard: View {
    let method: CheckoutPaymentMethod

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(background)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 18, x: 0, y: 10)

            logoContent
        }
    }

    @ViewBuilder
    private var logoContent: some View {
        switch method {
        case .applePay:
            // Apple Pay 品牌组合：apple.logo SF Symbol + 加粗 "Pay" 文字
            HStack(spacing: 6) {
                Image(systemName: "applelogo")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(.white)
                Text("Pay")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(.white)
            }
        case .tabby:
            // Tabby SVG 已包含浅绿底 + 深灰文字，整体作为 logo 块展示
            Image("TabbyLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 160)
        case .duPay:
            // du Pay SVG 是白色 logo（含圆角矩形外框），叠在红色卡片上
            Image("DuPayLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 140)
        }
    }

    private var background: Color {
        switch method {
        case .applePay: return Color.black
        // Tabby 卡片背景使用 SVG 同款薄荷绿，让 SVG 与卡片融合
        case .tabby:    return Color(hex: 0x5AFEAE)
        case .duPay:    return Color(hex: 0xE10600)
        }
    }
}

// MARK: - Sub-views

private struct CheckoutFeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let textSecondary: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(textSecondary)
                .frame(width: 32, height: 32)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(textSecondary)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct CheckoutPricingRow: View {
    let label: String
    let value: String
    let isTotal: Bool
    let textSecondary: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: isTotal ? 18 : 15, weight: isTotal ? .bold : .regular))
                .foregroundColor(isTotal ? .white : textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: isTotal ? 18 : 15, weight: isTotal ? .bold : .regular))
                .foregroundColor(isTotal ? .white : textSecondary)
        }
    }
}

// MARK: - Preview

struct CheckoutView_Previews: PreviewProvider {
    static var previews: some View {
        CheckoutView(
            summary: CheckoutSummary(
                planTitle: "Data First Plan",
                msisdn: "+971 50 123 4567",
                dataText: "150 GB",
                voiceText: "300 mins",
                billingPeriod: "Monthly",
                basePriceAED: 119.05,
                totalPriceAED: 125.00,
                vatRate: 0.05
            ),
            onBack: {},
            onPay: {}
        )
    }
}
