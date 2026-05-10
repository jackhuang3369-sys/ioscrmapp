import SwiftUI

struct PlanSelectionView: View {
    let numberSelection: NumberSelection
    let onBack: () -> Void
    // 套餐确认后向上传递结账摘要，进入结账页
    let onCheckout: (CheckoutSummary) -> Void

    @State private var activePlanIndex = 0
    @State private var mode: PlanSelectionMode = .carousel
    @State private var selectedPlanSummary: PlanKycSummary?
    // 与 selectedPlanSummary 同步构建，供结账回调使用
    @State private var pendingCheckoutSummary: CheckoutSummary?
    @State private var dataAmount: Double = 50
    @State private var cansAmount: Double = 30
    @State private var voiceAmount: Double = 500

    private let plans = PlanCatalog.mockPlans

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                PlanSelectionBackground()

                switch mode {
                case .carousel:
                    carouselScreen(safeTop: proxy.safeAreaInsets.top, safeBottom: proxy.safeAreaInsets.bottom)
                case .byop:
                    byopScreen(safeTop: proxy.safeAreaInsets.top, safeBottom: proxy.safeAreaInsets.bottom)
                case .kyc:
                    kycScreen(safeTop: proxy.safeAreaInsets.top, safeBottom: proxy.safeAreaInsets.bottom)
                }
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden(true)
    }

    private func carouselScreen(safeTop: CGFloat, safeBottom: CGFloat) -> some View {
        VStack(spacing: 0) {
            planHeader(safeTop: safeTop, onBack: onBack)

            VStack(spacing: 10) {
                Text("CHOOSE YOUR PLAN")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .tracking(7)
                    .foregroundColor(.white.opacity(0.42))

                Text("Pick your power")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .padding(.top, 15)

            PlanStageCarousel(plans: plans, activeIndex: $activePlanIndex)
                .frame(height: 548)
                .padding(.top, 10)

            PlanPager(count: plans.count, activeIndex: activePlanIndex)
                .padding(.top, 2)

            Button(action: handleSelectedPlan) {
                Text(plans[activePlanIndex].isBYOP ? "BUILD MY PLAN" : "SELECT THIS PLAN")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .tracking(4.8)
                    .foregroundColor(Color(hex: 0x1C1B24))
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: Color.white.opacity(0.14), radius: 28, x: 0, y: 14)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 26)
            .padding(.top, 16)

            Spacer(minLength: 8)
            PlanHomeIndicator()
                .padding(.bottom, max(safeBottom, 14))
        }
    }

    private func byopScreen(safeTop: CGFloat, safeBottom: CGFloat) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                planHeader(safeTop: safeTop, onBack: { mode = .carousel })

                VStack(alignment: .leading, spacing: 10) {
                    Text("MONTHLY BUILD")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .tracking(4)
                        .foregroundColor(.white.opacity(0.34))

                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(byopMonthlyPrice)")
                            .font(.system(size: 68, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: PlanPalette.red.opacity(0.25), radius: 28, x: 0, y: 0)

                        Text("AED")
                            .font(.system(size: 22, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.58))
                    }
                }
                .padding(.top, 15)

                HStack(spacing: 12) {
                    BYOPSummaryStat(value: "\(Int(dataAmount)) GB", label: "Data")
                    BYOPSummaryStat(value: String(format: "%03d", Int(cansAmount)), label: "Cans")
                    BYOPSummaryStat(value: "\(Int(voiceAmount))", label: "Flexi mins")
                }
                .padding(.top, 24)

                VStack(spacing: 28) {
                    BYOPSliderBlock(
                        title: "Customize your data",
                        symbol: "D",
                        accent: PlanPalette.cyan,
                        value: $dataAmount,
                        range: 10...120,
                        step: 5
                    )
                    BYOPSliderBlock(
                        title: "Customize your cans",
                        symbol: "R",
                        accent: PlanPalette.red,
                        value: $cansAmount,
                        range: 0...60,
                        step: 5
                    )
                    BYOPSliderBlock(
                        title: "Customize your Voice",
                        symbol: "V",
                        accent: PlanPalette.gold,
                        value: $voiceAmount,
                        range: 100...1200,
                        step: 50
                    )

                    Button(action: continueBYOPToKYC) {
                        Text("CONTINUE")
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .tracking(5)
                            .foregroundColor(Color(hex: 0x1C1B24))
                            .frame(maxWidth: .infinity)
                            .frame(height: 58)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
                .background(
                    LinearGradient(
                        colors: [PlanPalette.red.opacity(0.18), Color.white.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 32, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
                .padding(.top, 28)

                PlanHomeIndicator()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 26)
                    .padding(.bottom, max(safeBottom, 14))
            }
            .padding(.horizontal, 26)
        }
    }

    private func kycScreen(safeTop: CGFloat, safeBottom: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            planHeader(safeTop: safeTop, onBack: { mode = .carousel })

            VStack(alignment: .leading, spacing: 14) {
                Text("NEXT STEP")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .tracking(4)
                    .foregroundColor(.white.opacity(0.42))

                Text("Verify with UAE Pass")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .lineSpacing(2)

                Text("KYC starts after your plan is selected. This mock screen marks the routing target for preset plans and completed BYOP builds.")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.58))
                    .lineSpacing(5)

                VStack(alignment: .leading, spacing: 8) {
                    Text(selectedPlanSummary?.title ?? "Plan selected")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)

                    Text(selectedPlanSummary?.detail ?? "Ready for verification")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.54))
                        .lineSpacing(4)

                    Text("Number \(numberSelection.selectedMsisdn)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(PlanPalette.gold.opacity(0.9))
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.26), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .padding(.top, 8)
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            .background(
                LinearGradient(
                    colors: [PlanPalette.red.opacity(0.2), Color.white.opacity(0.045)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 32, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
            .padding(.horizontal, 26)
            .padding(.top, 54)

            Spacer()

            Button {
                // 套餐已确认，携带结账摘要进入结账支付页
                if let summary = pendingCheckoutSummary {
                    onCheckout(summary)
                }
            } label: {
                Text("PROCEED TO CHECKOUT")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .tracking(3.6)
                    .foregroundColor(Color(hex: 0x1C1B24))
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 26)

            PlanHomeIndicator()
                .frame(maxWidth: .infinity)
                .padding(.top, 18)
                .padding(.bottom, max(safeBottom, 14))
        }
    }

    private func planHeader(safeTop: CGFloat, onBack: @escaping () -> Void) -> some View {
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
        .padding(.horizontal, mode == .carousel ? 26 : 0)
    }

    private var byopMonthlyPrice: Int {
        // Mock 价格公式：基础费 + Data 单价 + Cans 单价 + Voice 单价，后续替换为真实资费引擎。
        Int((79 + dataAmount * 1.65 + cansAmount * 1.8 + voiceAmount * 0.038).rounded())
    }

    private func handleSelectedPlan() {
        let plan = plans[activePlanIndex]
        if plan.isBYOP {
            mode = .byop
        } else {
            selectedPlanSummary = PlanKycSummary(
                title: plan.title,
                detail: "\(plan.priceText) AED · \(plan.billing.rawValue) · \(plan.dataText) Data · \(plan.cansText) Cans · \(plan.voiceText) Voice mins"
            )
            // 同步构建结账摘要：tax-inclusive total，base = total / 1.05 向下取整至分
            let total = Double(plan.price!)
            let base = (total / 1.05 * 100).rounded(.down) / 100
            pendingCheckoutSummary = CheckoutSummary(
                planTitle: plan.title,
                msisdn: numberSelection.selectedMsisdn,
                dataText: plan.dataText,
                voiceText: "\(plan.voiceMins) mins",
                billingPeriod: plan.billing.rawValue,
                basePriceAED: base,
                totalPriceAED: total,
                vatRate: 0.05
            )
            mode = .kyc
        }
    }

    private func continueBYOPToKYC() {
        selectedPlanSummary = PlanKycSummary(
            title: "Build Your Own Plan",
            detail: "\(byopMonthlyPrice) AED · Monthly · \(Int(dataAmount)) GB Data · \(Int(cansAmount)) Cans · \(Int(voiceAmount)) Voice mins"
        )
        // BYOP 价格已含税，同样向下取整 base
        let total = Double(byopMonthlyPrice)
        let base = (total / 1.05 * 100).rounded(.down) / 100
        pendingCheckoutSummary = CheckoutSummary(
            planTitle: "Build Your Own Plan",
            msisdn: numberSelection.selectedMsisdn,
            dataText: "\(Int(dataAmount)) GB",
            voiceText: "\(Int(voiceAmount)) mins",
            billingPeriod: "Monthly",
            basePriceAED: base,
            totalPriceAED: total,
            vatRate: 0.05
        )
        mode = .kyc
    }
}

private enum PlanSelectionMode {
    case carousel
    case byop
    case kyc
}

private struct PlanKycSummary: Equatable {
    let title: String
    let detail: String
}

private enum PlanBilling: String {
    case monthly = "Monthly"
    case yearly = "Yearly"
}

private struct PlanOption: Identifiable, Equatable {
    let id = UUID()
    let type: String
    let title: String
    let copy: String
    let price: Int?
    let billing: PlanBilling
    let dataGB: Int
    let cans: Int
    let voiceMins: Int
    let featured: String
    let glow: Color

    var isBYOP: Bool { price == nil }
    var priceText: String { price.map(String.init) ?? "Live" }
    var dataText: String { "\(dataGB)GB" }
    var cansText: String { "\(cans)" }
    var voiceText: String { "\(voiceMins)" }
}

private enum PlanCatalog {
    static let mockPlans: [PlanOption] = [
        PlanOption(
            type: "BYOP",
            title: "Build Your Own Plan",
            copy: "Tune data, cans, and voice around your monthly rhythm.",
            price: nil,
            billing: .monthly,
            dataGB: 50,
            cans: 30,
            voiceMins: 500,
            featured: "Custom",
            glow: PlanPalette.red.opacity(0.28)
        ),
        PlanOption(
            type: "BOOST",
            title: "Event Zone Boost",
            copy: "More data and Red Bull rewards for high-energy weekends.",
            price: 199,
            billing: .monthly,
            dataGB: 80,
            cans: 20,
            voiceMins: 700,
            featured: "Popular",
            glow: PlanPalette.cyan.opacity(0.24)
        ),
        PlanOption(
            type: "ULTRA",
            title: "Unlimited Pulse",
            copy: "The flagship mobile power pack for always-on UAE days.",
            price: 1899,
            billing: .yearly,
            dataGB: 150,
            cans: 45,
            voiceMins: 1200,
            featured: "Annual",
            glow: PlanPalette.gold.opacity(0.22)
        )
    ]
}

private enum PlanPalette {
    static let red = Color(hex: 0xFF1235)
    static let gold = Color(hex: 0xF4C15D)
    static let cyan = Color(hex: 0x13C8FF)
    static let violet = Color(hex: 0x8478FF)
    static let canvas = Color(hex: 0x030305)
}

private struct PlanSelectionBackground: View {
    var body: some View {
        ZStack {
            PlanPalette.canvas

            RadialGradient(
                colors: [PlanPalette.red.opacity(0.24), .clear],
                center: .topTrailing,
                startRadius: 24,
                endRadius: 330
            )

            RadialGradient(
                colors: [PlanPalette.cyan.opacity(0.13), .clear],
                center: .bottomLeading,
                startRadius: 28,
                endRadius: 280
            )

            GridField()

            LinearGradient(
                colors: [Color.black.opacity(0.05), Color.black.opacity(0.74)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

private struct GridField: View {
    var body: some View {
        GeometryReader { proxy in
            Path { path in
                let step: CGFloat = 44
                stride(from: CGFloat.zero, through: proxy.size.width, by: step).forEach { x in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: proxy.size.height))
                }
                stride(from: CGFloat.zero, through: proxy.size.height, by: step).forEach { y in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                }
            }
            .stroke(Color.white.opacity(0.025), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

private struct PlanStageCarousel: View {
    let plans: [PlanOption]
    @Binding var activeIndex: Int
    @GestureState private var dragOffset: CGFloat = 0

    private let cardWidth: CGFloat = 306
    private let cardSpacing: CGFloat = 238

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(Array(plans.enumerated()), id: \.element.id) { index, plan in
                    let metrics = cardMetrics(for: index)

                    PlanCarouselCard(plan: plan, focus: metrics.focus)
                        .frame(width: cardWidth)
                        .scaleEffect(metrics.scale)
                        .rotation3DEffect(
                            .degrees(metrics.rotation),
                            axis: (x: 0, y: 1, z: 0),
                            anchor: .center,
                            perspective: 0.72
                        )
                        .offset(x: metrics.x)
                        .opacity(metrics.opacity)
                        .saturation(metrics.saturation)
                        .brightness(metrics.brightness)
                        .blur(radius: metrics.blur)
                        .zIndex(metrics.zIndex)
                        .contentShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                        .onTapGesture {
                            // 旁边卡片点击后成为焦点，和 HTML 原型的卡片点击逻辑保持一致。
                            withAnimation(.interactiveSpring(response: 0.42, dampingFraction: 0.86)) {
                                activeIndex = index
                            }
                        }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .contentShape(Rectangle())
            .gesture(stageDragGesture)
            .animation(.interactiveSpring(response: 0.42, dampingFraction: 0.86), value: activeIndex)
        }
    }

    private var stageDragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($dragOffset) { value, state, _ in
                // 拖拽中的位移直接参与 3D 参数计算，让卡片在手指移动时实时产生透视变化。
                state = value.translation.width
            }
            .onEnded { value in
                let predicted = value.predictedEndTranslation.width
                let threshold: CGFloat = 62
                var nextIndex = activeIndex

                if predicted < -threshold {
                    nextIndex += 1
                } else if predicted > threshold {
                    nextIndex -= 1
                }

                withAnimation(.interactiveSpring(response: 0.42, dampingFraction: 0.86)) {
                    activeIndex = min(max(nextIndex, 0), plans.count - 1)
                }
            }
    }

    private func cardMetrics(for index: Int) -> PlanCarouselCardMetrics {
        let rawPosition = CGFloat(index - activeIndex) + dragOffset / cardSpacing
        let clampedPosition = min(max(rawPosition, -1.35), 1.35)
        let distance = min(abs(clampedPosition), 1)
        let x = rawPosition * cardSpacing

        return PlanCarouselCardMetrics(
            x: x,
            scale: 1 - distance * 0.18,
            rotation: Double(clampedPosition * -16),
            opacity: abs(rawPosition) > 1.45 ? 0 : 1 - distance * 0.54,
            saturation: 1 - distance * 0.28,
            brightness: -distance * 0.08,
            blur: distance * 0.35,
            focus: 1 - distance,
            zIndex: Double(100 - abs(rawPosition) * 10)
        )
    }
}

private struct PlanCarouselCardMetrics {
    let x: CGFloat
    let scale: CGFloat
    let rotation: Double
    let opacity: CGFloat
    let saturation: Double
    let brightness: Double
    let blur: CGFloat
    let focus: CGFloat
    let zIndex: Double
}

private struct PlanCarouselCard: View {
    let plan: PlanOption
    let focus: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(plan.type)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(3)
                .foregroundColor(PlanPalette.gold)

            Text(plan.title)
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .lineSpacing(-2)
                .minimumScaleFactor(0.75)
                .padding(.top, 18)

            Text(plan.copy)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.56))
                .lineSpacing(4)
                .padding(.top, 12)

            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(plan.priceText)
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    Text(plan.isBYOP ? "AED ESTIMATE" : "AED")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(2)
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                Text(plan.billing.rawValue.uppercased())
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.4)
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .frame(height: 36)
                    .background(PlanPalette.red.opacity(0.2), in: Capsule())
                    .overlay(Capsule().stroke(PlanPalette.red.opacity(0.36), lineWidth: 1))
            }
            .padding(14)
            .background(Color.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .padding(.top, 18)

            PlanPowerCore(plan: plan)
                .frame(maxWidth: .infinity)
                .padding(.top, 20)

            HStack(spacing: 8) {
                PlanResourcePill(value: plan.dataText, label: "Data")
                PlanResourcePill(value: plan.cansText, label: "Cans")
                PlanResourcePill(value: plan.voiceText, label: "Voice")
            }
            .padding(.top, 22)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .frame(height: 532, alignment: .top)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.11), Color.white.opacity(0.035)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(plan.glow)
                    .blur(radius: 38)
                    .opacity(0.35 + 0.45 * focus)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .stroke(
                    AngularGradient(
                        colors: [PlanPalette.red, PlanPalette.gold, PlanPalette.cyan, PlanPalette.violet, PlanPalette.red],
                        center: .center
                    ),
                    lineWidth: 3.2
                )
                .blur(radius: 8)
                .opacity(0.12 + 0.64 * focus)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            PlanPalette.red.opacity(0.35 + 0.55 * focus),
                            PlanPalette.gold.opacity(0.24 + 0.46 * focus),
                            PlanPalette.cyan.opacity(0.32 + 0.53 * focus)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.4
                )
        )
        .shadow(color: PlanPalette.red.opacity(0.04 + 0.18 * focus), radius: 26 + 18 * focus, x: 0, y: 0)
        .shadow(color: Color.black.opacity(0.46 + 0.1 * focus), radius: 30, x: 0, y: 22)
    }
}

private struct PlanPowerCore: View {
    let plan: PlanOption
    @State private var isBreathing = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [PlanPalette.red, PlanPalette.gold, PlanPalette.cyan, PlanPalette.violet, PlanPalette.red],
                        center: .center
                    ),
                    lineWidth: 18
                )
                .frame(width: 156, height: 156)
                .shadow(color: PlanPalette.red.opacity(isBreathing ? 0.38 : 0.18), radius: isBreathing ? 26 : 12, x: 0, y: 0)
                .scaleEffect(isBreathing ? 1.035 : 0.985)

            Circle()
                .fill(Color.black.opacity(0.72))
                .frame(width: 116, height: 116)
                .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 1))

            VStack(spacing: 4) {
                Text(plan.featured)
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.7)
                Text(plan.isBYOP ? "BUILD" : "PLAN")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(1.5)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
        }
    }
}

private struct PlanResourcePill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(0.56))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 62)
        .background(Color.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.09), lineWidth: 1)
        )
    }
}

private struct PlanPager: View {
    let count: Int
    let activeIndex: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == activeIndex ? Color.white : Color.white.opacity(0.28))
                    .frame(width: index == activeIndex ? 25 : 7, height: 7)
                    .animation(.easeInOut(duration: 0.2), value: activeIndex)
            }
        }
    }
}

private struct BYOPSummaryStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(label)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(0.56))
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 74)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.11), lineWidth: 1)
        )
    }
}

private struct BYOPSliderBlock: View {
    let title: String
    let symbol: String
    let accent: Color
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accent)
                        .frame(width: 34, height: 34)
                        .shadow(color: accent.opacity(0.45), radius: 16, x: 0, y: 0)

                    Text(symbol)
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                }

                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.86))
            }

            Slider(value: $value, in: range, step: step)
                .tint(accent)
        }
    }
}

private struct PlanHomeIndicator: View {
    var body: some View {
        Capsule()
            .fill(Color(hex: 0xA0A1D6, opacity: 0.8))
            .frame(width: 148, height: 4)
    }
}

struct PlanSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        PlanSelectionView(
            numberSelection: NumberSelection(
                numberType: .standard,
                selectedMsisdn: "+971 50 123 4567",
                lockId: "preview-lock"
            ),
            onBack: {},
            onCheckout: { _ in }
        )
        .duTheme(mode: .dark)
    }
}
