import SwiftUI
import ARKit
import SceneKit

struct ARPlacementView: UIViewRepresentable {
    let coordinator: ARSceneCoordinator

    func makeCoordinator() -> ARSceneCoordinator { coordinator }

    func makeUIView(context: Context) -> ARSCNView {
        let sceneView = ARSCNView()
        sceneView.delegate = context.coordinator
        sceneView.autoenablesDefaultLighting = true
        sceneView.automaticallyUpdatesLighting = true
        context.coordinator.sceneView = sceneView

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        sceneView.session.run(config)

        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(ARSceneCoordinator.handleTapGesture(_:)))
        sceneView.addGestureRecognizer(tap)

        return sceneView
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}
}

extension ARSceneCoordinator {
    @objc func handleTapGesture(_ sender: UITapGestureRecognizer) {
        guard let sceneView else { return }
        handleTap(at: sender.location(in: sceneView))
    }
}
