import SwiftUI
import UIKit

struct MallImagePreviewContext: Identifiable {
    let id = UUID()
    let images: [MallImageSource]
    let initialIndex: Int

    init(images: [MallImageSource], initialIndex: Int = 0) {
        self.images = images
        self.initialIndex = initialIndex
    }

    static func single(_ image: MallImageSource) -> Self {
        Self(images: [image], initialIndex: 0)
    }
}

struct MallImagePreviewScreen: View {
    @Environment(\.duTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    let images: [MallImageSource]

    @State private var selectedIndex: Int

    init(images: [MallImageSource], initialIndex: Int = 0) {
        self.images = images
        _selectedIndex = State(
            initialValue: min(max(initialIndex, 0), max(images.count - 1, 0))
        )
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            DUColorPrimitives.Neutral.black
                .ignoresSafeArea()

            TabView(selection: $selectedIndex) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                    MallZoomableImagePage(image: image)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: images.count > 1 ? .always : .never))
            .ignoresSafeArea()

            previewToolbar
        }
        .background(DUColorPrimitives.Neutral.black)
    }

    private var previewToolbar: some View {
        HStack(spacing: DUSpacing.md) {
            if images.count > 1 {
                Text("\(selectedIndex + 1) / \(images.count)")
                    .font(.du(.bodyStrong))
                    .foregroundColor(MallPalette(theme: theme).inverseText.opacity(0.92))
            }

            Spacer(minLength: 0)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.du(.bodyLargeStrong))
                    .foregroundColor(MallPalette(theme: theme).inverseText)
                    .frame(width: 34, height: 34)
                    .background(MallPalette(theme: theme).inverseText.opacity(0.14))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DUSpacing.lg)
        .padding(.top, DUSpacing.xxxl)
    }
}

private struct MallZoomableImagePage: View {
    let image: MallImageSource

    var body: some View {
        MallZoomableScrollView {
            MallImagePreviewContent(image: image)
        }
        .ignoresSafeArea()
    }
}

private struct MallImagePreviewContent: View {
    @Environment(\.duTheme) private var theme

    let image: MallImageSource

    var body: some View {
        let palette = MallPalette(theme: theme)

        Group {
            switch image {
            case let .asset(name):
                Image(name)
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()

            case let .remote(url):
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(palette.inverseText)

                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFit()

                    default:
                        MallImagePreviewFallbackView()
                    }
                }

            case let .system(name, backgroundHex, tintHex):
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(Color(hex: backgroundHex))
                    .overlay(
                        Image(systemName: name)
                            .font(.du(.display))
                            .foregroundColor(Color(hex: tintHex))
                    )
                    .padding(DUSpacing.xxxl)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DUColorPrimitives.Neutral.black)
    }
}

private struct MallImagePreviewFallbackView: View {
    var body: some View {
        VStack(spacing: DUSpacing.md) {
            Image(systemName: "photo")
                .font(.du(.display))
                .foregroundColor(DUColorPrimitives.Neutral.white.opacity(0.88))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct MallZoomableScrollView<Content: View>: UIViewRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(rootView: content)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .clear
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 4
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never

        let hostedView = context.coordinator.hostingController.view
        hostedView?.backgroundColor = .clear
        hostedView?.frame = scrollView.bounds
        hostedView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        if let hostedView {
            scrollView.addSubview(hostedView)
        }

        let doubleTapRecognizer = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTapRecognizer.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTapRecognizer)

        context.coordinator.attach(scrollView)
        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.hostingController.rootView = content
        context.coordinator.updateLayout(in: scrollView)
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        let hostingController: UIHostingController<Content>

        private weak var scrollView: UIScrollView?

        init(rootView: Content) {
            hostingController = UIHostingController(rootView: rootView)
            hostingController.view.backgroundColor = .clear
        }

        func attach(_ scrollView: UIScrollView) {
            self.scrollView = scrollView
            updateLayout(in: scrollView)
        }

        func updateLayout(in scrollView: UIScrollView) {
            hostingController.view.frame = scrollView.bounds
            scrollView.contentSize = scrollView.bounds.size
            centerContent(in: scrollView)
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            hostingController.view
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerContent(in: scrollView)
        }

        @objc
        func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
            guard let scrollView else {
                return
            }

            if scrollView.zoomScale > scrollView.minimumZoomScale {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
                return
            }

            let tapLocation = recognizer.location(in: hostingController.view)
            let zoomRect = zoomRect(
                for: min(scrollView.maximumZoomScale, 2.5),
                center: tapLocation,
                in: scrollView
            )
            scrollView.zoom(to: zoomRect, animated: true)
        }

        private func centerContent(in scrollView: UIScrollView) {
            let horizontalInset = max((scrollView.bounds.width - scrollView.contentSize.width) * 0.5, 0)
            let verticalInset = max((scrollView.bounds.height - scrollView.contentSize.height) * 0.5, 0)

            hostingController.view.center = CGPoint(
                x: scrollView.contentSize.width * 0.5 + horizontalInset,
                y: scrollView.contentSize.height * 0.5 + verticalInset
            )
        }

        private func zoomRect(
            for scale: CGFloat,
            center: CGPoint,
            in scrollView: UIScrollView
        ) -> CGRect {
            let width = scrollView.bounds.width / scale
            let height = scrollView.bounds.height / scale

            return CGRect(
                x: center.x - width * 0.5,
                y: center.y - height * 0.5,
                width: width,
                height: height
            )
        }
    }
}
