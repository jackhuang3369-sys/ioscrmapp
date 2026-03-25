import SwiftUI

struct MallContainerView: View {
    @StateObject private var viewModel: MallViewModel

    init(
        session: CustSubInfo,
        mallService: any MallServicing
    ) {
        _viewModel = StateObject(
            wrappedValue: MallViewModel(
                session: session,
                mallService: mallService
            )
        )
    }

    var body: some View {
        NavigationView {
            MallHomeView(viewModel: viewModel)
        }
        .navigationViewStyle(.stack)
    }
}
