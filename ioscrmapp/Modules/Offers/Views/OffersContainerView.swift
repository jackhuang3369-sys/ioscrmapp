import SwiftUI

struct OffersContainerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageStore: AppLanguageStore
    @StateObject private var viewModel: OffersViewModel
    @StateObject private var diyViewModel: DIYOfferViewModel
    @State private var isDIYPresented = false

    init(session: CustSubInfo, offersService: any OffersServicing) {
        _viewModel = StateObject(
            wrappedValue: OffersViewModel(session: session, offersService: offersService)
        )
        _diyViewModel = StateObject(
            wrappedValue: DIYOfferViewModel(session: session, offersService: offersService)
        )
    }

    var body: some View {
        NavigationView {
            OffersLandingView(
                viewModel: viewModel,
                onOpenDIY: {
                    isDIYPresented = true
                }
            )
                .background(purchaseNavigationLink)
                .background(diyNavigationLink)
                .background(orderNavigationLink)
                .navigationTitle(localized("offers.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(localized("common.cancel")) {
                            dismiss()
                        }
                    }
                }
        }
        .navigationViewStyle(.stack)
        .task {
            await viewModel.loadLandingIfNeeded()
        }
        .fullScreenCover(item: $viewModel.acceptedResult) { result in
            OffersAcceptedResultView(
                result: result,
                onContinue: {
                    viewModel.handleAcceptedResultDismiss()
                }
            )
        }
        .alert(isPresented: Binding(
            get: { viewModel.toastMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.dismissToast()
                }
            }
        )) {
            Alert(
                title: Text(localized("offers.failure.title")),
                message: Text(localized(viewModel.toastMessage)),
                dismissButton: .default(Text(localized("common.ok"))) {
                    viewModel.dismissToast()
                }
            )
        }
    }

    private var purchaseNavigationLink: some View {
        NavigationLink(
            destination: OffersPurchaseListView(viewModel: viewModel),
            isActive: $viewModel.isPurchaseListPresented
        ) {
            EmptyView()
        }
        .hidden()
    }

    private var diyNavigationLink: some View {
        NavigationLink(
            destination: DIYOfferBuilderView(
                viewModel: diyViewModel,
                onViewOrders: {
                    isDIYPresented = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        viewModel.openOrderList(entry: .diy)
                    }
                },
                onBackToOffers: {
                    isDIYPresented = false
                }
            ),
            isActive: $isDIYPresented
        ) {
            EmptyView()
        }
        .hidden()
    }

    private var orderNavigationLink: some View {
        NavigationLink(
            destination: OffersOrdersView(viewModel: viewModel),
            isActive: $viewModel.isOrderListPresented
        ) {
            EmptyView()
        }
        .hidden()
    }

    private func localized(_ key: String, arguments: [String] = []) -> String {
        languageStore.string(key, arguments: arguments)
    }

    private func localized(_ value: LocalizedTextValue?) -> String {
        languageStore.string(value)
    }
}

struct OffersContainerView_Previews: PreviewProvider {
    private static let previewSession = CustSubInfo(
        displayName: "Ahmed Mohammed",
        phoneNumber: AuthValidator.demoPhone,
        greeting: "Good Morning",
        balanceText: "128.50 AED",
        userID: "preview-user",
        serviceNumber: AuthValidator.demoPhone
    )

    private static let englishStore = AppLanguageStore(initialLanguage: .english)
    private static let arabicStore = AppLanguageStore(initialLanguage: .arabic)

    static var previews: some View {
        Group {
            OffersContainerView(
                session: previewSession,
                offersService: MockOffersService()
            )
            .environmentObject(englishStore)
            .environment(\.layoutDirection, englishStore.layoutDirection)
            .previewDisplayName("Offers EN")

            OffersContainerView(
                session: previewSession,
                offersService: MockOffersService()
            )
            .environmentObject(arabicStore)
            .environment(\.layoutDirection, arabicStore.layoutDirection)
            .previewDisplayName("Offers AR")
        }
    }
}
