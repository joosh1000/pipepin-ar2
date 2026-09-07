import SwiftUI
import RealityKit

struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var controller: ARSessionController
    @ObservedObject var markerStore: MarkerStore

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero)
        view.automaticallyConfigureSession = false
        controller.configure(view, markerStore: markerStore)

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tap)
        context.coordinator.arView = view
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    final class Coordinator: NSObject {
        let controller: ARSessionController
        weak var arView: ARView?

        init(controller: ARSessionController) {
            self.controller = controller
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let view = arView else { return }
            let point = recognizer.location(in: view)
            Task { @MainActor in
                controller.placeMarker(screenPoint: point)
            }
        }
    }
}
