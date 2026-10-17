import ARKit
import SceneKit

final class ARSceneCoordinator: NSObject, ARSCNViewDelegate {
    weak var sceneView: ARSCNView?

    var onPlaneTap: ((_ worldPos: SCNVector3, _ normal: SCNVector3) -> Void)?

    private var planeNodes: [ARAnchor: SCNNode] = [:]

    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        let planeNode = makePlaneNode(for: planeAnchor)
        node.addChildNode(planeNode)
        planeNodes[anchor] = planeNode
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor,
              let planeNode = planeNodes[anchor]?.childNodes.first,
              let plane = planeNode.geometry as? SCNPlane else { return }
        plane.width = CGFloat(planeAnchor.planeExtent.width)
        plane.height = CGFloat(planeAnchor.planeExtent.height)
        planeNode.simdPosition = planeAnchor.center
    }

    func handleTap(at location: CGPoint) {
        guard let sceneView else { return }
        let hitResults = sceneView.hitTest(location, types: [.existingPlaneUsingExtent, .estimatedHorizontalPlane])
        if let hit = hitResults.first {
            let worldPos = SCNVector3(hit.worldTransform.columns.3.x,
                                     hit.worldTransform.columns.3.y,
                                     hit.worldTransform.columns.3.z)
            let normal = SCNVector3(hit.worldTransform.columns.1.x,
                                   hit.worldTransform.columns.1.y,
                                   hit.worldTransform.columns.1.z)
            onPlaneTap?(worldPos, normal)
        }
    }

    func addAnchorPin(at position: SCNVector3, label: String, status: String) -> SCNNode {
        let color: UIColor = {
            switch status {
            case "surplus":     return .systemGreen
            case "claimed":     return .systemOrange
            case "transferred": return .systemGray
            case "in_use":      return .systemRed
            default:            return .systemYellow
            }
        }()

        let sphere = SCNSphere(radius: 0.04)
        sphere.firstMaterial?.diffuse.contents = color
        let pin = SCNNode(geometry: sphere)
        pin.position = position

        let text = SCNText(string: label.isEmpty ? "Item" : label, extrusionDepth: 0.01)
        text.font = UIFont.systemFont(ofSize: 0.1)
        text.firstMaterial?.diffuse.contents = UIColor.white
        let textNode = SCNNode(geometry: text)
        textNode.scale = SCNVector3(0.3, 0.3, 0.3)
        textNode.position = SCNVector3(0, 0.07, 0)

        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        textNode.constraints = [billboard]

        pin.addChildNode(textNode)
        sceneView?.scene.rootNode.addChildNode(pin)
        return pin
    }

    private func makePlaneNode(for anchor: ARPlaneAnchor) -> SCNNode {
        let plane = SCNPlane(width: CGFloat(anchor.planeExtent.width),
                             height: CGFloat(anchor.planeExtent.height))
        plane.firstMaterial?.diffuse.contents = UIColor.systemBlue.withAlphaComponent(0.1)
        plane.firstMaterial?.isDoubleSided = true
        let node = SCNNode(geometry: plane)
        node.simdPosition = anchor.center
        node.eulerAngles.x = -.pi / 2
        return node
    }
}
