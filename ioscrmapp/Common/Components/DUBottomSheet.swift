import SwiftUI
import UIKit

extension View {
    func duBottomSheet<SheetContent: View>(
        isPresented: Binding<Bool>,
        preferredHeight: CGFloat,
        showsGrabber: Bool = true,
        @ViewBuilder content: @escaping () -> SheetContent
    ) -> some View {
        modifier(
            DUBottomSheetModifier(
                isPresented: isPresented,
                preferredHeight: preferredHeight,
                showsGrabber: showsGrabber,
                sheetContent: content
            )
        )
    }
}

private struct DUBottomSheetModifier<SheetContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let preferredHeight: CGFloat
    let showsGrabber: Bool
    let sheetContent: () -> SheetContent

    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.sheet(isPresented: $isPresented) {
                sheetContent()
                    .presentationDetents([.height(preferredHeight)])
                    .presentationDragIndicator(showsGrabber ? .visible : .hidden)
            }
        } else {
            content.background(
                DULegacyBottomSheetPresenter(
                    isPresented: $isPresented,
                    preferredHeight: preferredHeight,
                    showsGrabber: showsGrabber,
                    sheetContent: sheetContent
                )
                .frame(width: 0, height: 0)
            )
        }
    }
}

private struct DULegacyBottomSheetPresenter<SheetContent: View>: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let preferredHeight: CGFloat
    let showsGrabber: Bool
    let sheetContent: () -> SheetContent

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        viewController.view.backgroundColor = .clear
        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        context.coordinator.isPresented = $isPresented

        if isPresented {
            context.coordinator.presentIfNeeded(
                from: uiViewController,
                preferredHeight: preferredHeight,
                showsGrabber: showsGrabber,
                rootView: AnyView(sheetContent())
            )
        } else {
            context.coordinator.dismissIfNeeded()
        }
    }

    final class Coordinator: NSObject, UIAdaptivePresentationControllerDelegate {
        var isPresented: Binding<Bool>
        weak var presentedController: UIHostingController<AnyView>?

        init(isPresented: Binding<Bool>) {
            self.isPresented = isPresented
        }

        func presentIfNeeded(
            from presentingViewController: UIViewController,
            preferredHeight: CGFloat,
            showsGrabber: Bool,
            rootView: AnyView
        ) {
            if let presentedController {
                presentedController.rootView = rootView
                return
            }

            let hostingController = UIHostingController(rootView: rootView)
            hostingController.view.backgroundColor = .clear
            hostingController.modalPresentationStyle = .pageSheet
            hostingController.presentationController?.delegate = self

            if let sheetController = hostingController.sheetPresentationController {
                let useMediumDetent = preferredHeight <= UIScreen.main.bounds.height * 0.55
                sheetController.detents = useMediumDetent ? [.medium(), .large()] : [.large()]
                sheetController.selectedDetentIdentifier = useMediumDetent ? .medium : .large
                sheetController.prefersGrabberVisible = showsGrabber
                sheetController.preferredCornerRadius = 24
                sheetController.prefersScrollingExpandsWhenScrolledToEdge = false
            }

            presentedController = hostingController
            presentingViewController.present(hostingController, animated: true)
        }

        func dismissIfNeeded() {
            guard let presentedController else {
                return
            }

            presentedController.dismiss(animated: true)
            self.presentedController = nil
        }

        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            isPresented.wrappedValue = false
            presentedController = nil
        }
    }
}
