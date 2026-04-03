import SwiftUI

struct VideoContainerView: View {
    @StateObject private var viewModel: VideoViewModel
    @Binding private var requestedVideoID: String?
    private let isActive: Bool

    init(
        session: CustSubInfo,
        videoService: any VideoServicing,
        requestedVideoID: Binding<String?> = .constant(nil),
        isActive: Bool = true
    ) {
        _requestedVideoID = requestedVideoID
        self.isActive = isActive
        _viewModel = StateObject(
            wrappedValue: VideoViewModel(
                session: session,
                videoService: videoService
            )
        )
    }

    var body: some View {
        NavigationView {
            VideoHomeView(
                viewModel: viewModel,
                requestedVideoID: $requestedVideoID,
                isActive: isActive
            )
        }
        .navigationViewStyle(.stack)
    }
}
