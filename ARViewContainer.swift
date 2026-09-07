import SwiftUI
import RealityKit

struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var controller: ARSessionController
    @ObservedObject var markerStore: MarkerStore

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero)
        view.automaticallyConfigureSession = false
        controller.configure(view, markerStore: markerStore)
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}
