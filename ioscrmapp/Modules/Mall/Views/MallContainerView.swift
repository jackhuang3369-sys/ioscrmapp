import SwiftUI

struct MallContainerView: View {
    @StateObject private var viewModel: MallViewModel
    private let onBackToAppHome: () -> Void

    init(
        session: CustSubInfo,
        mallService: any MallServicing,
        onBackToAppHome: @escaping () -> Void
    ) {
        self.onBackToAppHome = onBackToAppHome
        _viewModel = StateObject(
            wrappedValue: MallViewModel(
                session: session,
                mallService: mallService
            )
        )
    }

    var body: some View {
        NavigationView {
            MallHomeView(
                viewModel: viewModel,
                onBackToAppHome: onBackToAppHome
            )
        }
        .navigationViewStyle(.stack)
    }
}
