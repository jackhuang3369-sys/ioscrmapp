import SwiftUI

struct VideoContainerView: View {
    @StateObject private var viewModel: VideoViewModel

    init(
        session: CustSubInfo,
        videoService: any VideoServicing
    ) {
        _viewModel = StateObject(
            wrappedValue: VideoViewModel(
                session: session,
                videoService: videoService
            )
        )
    }

    var body: some View {
        NavigationView {
            VideoHomeView(viewModel: viewModel)
        }
        .navigationViewStyle(.stack)
    }
}
