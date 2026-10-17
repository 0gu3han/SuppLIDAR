import SwiftUI
import ARKit
import SceneKit
import CoreImage

// Defined here to avoid touching Models.swift (owned by teammate)
struct DetectionResult: Codable {
    let name: String
    let category: String
    let condition: String
    let description: String
    let photo_url: String
    let vision_labels: [String]
    let ocr_text: [String]
}

struct DetectedPin: Identifiable {
    let id: Int          // object_id from backend
    let anchorId: Int
    let name: String
    let category: String
    let condition: String
    let position: SCNVector3
}

// MARK: - Main View

struct ItemDetectionView: View {
    let roomId: Int
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = ItemDetectionViewModel()
    @State private var showList = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ItemDetectionARView(vm: vm, roomId: roomId)
                .ignoresSafeArea()

            // Top bar
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2).foregroundColor(.white)
                            .shadow(color: .black.opacity(0.4), radius: 4)
                    }

                    Spacer()

                    statusBanner

                    Spacer()

                    Button(action: { showList = true }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "list.bullet.circle.fill")
                                .font(.title2).foregroundColor(.white)
                                .shadow(color: .black.opacity(0.4), radius: 4)
                            if !vm.detectedPins.isEmpty {
                                Text("\(vm.detectedPins.count)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(3)
                                    .background(Color.red)
                                    .clipShape(Circle())
                                    .offset(x: 6, y: -6)
                            }
                        }
                    }
                    .disabled(vm.detectedPins.isEmpty)
                }
                .padding()
                Spacer()

                // Error banner at bottom
                if let err = vm.errorMessage {
                    Text(err)
                        .font(.caption).foregroundColor(.white)
                        .padding(10).background(Color.red.opacity(0.85))
                        .cornerRadius(8).padding(.bottom, 32)
                }
            }
        }
        .sheet(isPresented: $showList) {
            DetectedItemsListView(pins: vm.detectedPins)
        }
    }

    @ViewBuilder
    private var statusBanner: some View {
        if vm.isAnalyzing {
            HStack(spacing: 6) {
                ProgressView().scaleEffect(0.75).tint(.white)
                Text("OCI Vision detecting...").font(.caption).foregroundColor(.white)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(.ultraThinMaterial).cornerRadius(8)
        } else {
            Text("Tap an item to detect it")
                .font(.caption).foregroundColor(.white)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(.ultraThinMaterial).cornerRadius(8)
        }
    }
}

// MARK: - Detected Items Sheet

struct DetectedItemsListView: View {
    let pins: [DetectedPin]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List(pins) { pin in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(pin.name).font(.headline)
                        Spacer()
                        Label("in_use", systemImage: "circle.fill")
                            .font(.caption2).foregroundColor(.red)
                    }
                    Text(pin.category.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.caption).foregroundColor(.secondary)
                    Text("Condition: \(pin.condition)").font(.caption).foregroundColor(.secondary)
                }
            }
            .navigationTitle("\(pins.count) item\(pins.count == 1 ? "" : "s") detected")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - ViewModel

@MainActor
final class ItemDetectionViewModel: ObservableObject {
    @Published var detectedPins: [DetectedPin] = []
    @Published var isAnalyzing = false
    @Published var errorMessage: String?

    func detect(roomId: Int, imageData: Data, pos: [Float], normal: [Float], sceneView: ARSCNView) async {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        errorMessage = nil

        do {
            // 1. OCI Vision + Gen AI via backend
            let result = try await APIClient.shared.detectPhoto(imageData: imageData)

            // 2. Create anchor at tapped world position
            let anchorId = try await APIClient.shared.createAnchor(
                roomId: roomId,
                label: result.name,
                pos: pos,
                normal: normal
            )

            // 3. Store as Object (status embedded in body until Item model is ready)
            let body = """
            Category: \(result.category)
            Condition: \(result.condition)
            Status: in_use
            \(result.description)
            Labels: \(result.vision_labels.joined(separator: ", "))
            OCR: \(result.ocr_text.joined(separator: " | "))
            """
            let objectId = try await APIClient.shared.createObject(
                anchorId: anchorId,
                title: result.name,
                kind: "text",
                body: body
            )

            let worldPos = SCNVector3(pos[0], pos[1], pos[2])
            let pin = DetectedPin(
                id: objectId,
                anchorId: anchorId,
                name: result.name.isEmpty ? "Unknown item" : result.name,
                category: result.category,
                condition: result.condition,
                position: worldPos
            )
            detectedPins.append(pin)
            addARPin(pin: pin, sceneView: sceneView)

        } catch {
            errorMessage = error.localizedDescription
        }

        isAnalyzing = false
    }

    private func addARPin(pin: DetectedPin, sceneView: ARSCNView) {
        // Red sphere = in_use
        let sphere = SCNSphere(radius: 0.04)
        sphere.firstMaterial?.diffuse.contents = UIColor.systemRed
        let pinNode = SCNNode(geometry: sphere)
        pinNode.position = pin.position

        // Floating label
        let text = SCNText(string: pin.name, extrusionDepth: 0.005)
        text.font = UIFont.systemFont(ofSize: 0.1, weight: .semibold)
        text.firstMaterial?.diffuse.contents = UIColor.white
        let textNode = SCNNode(geometry: text)
        textNode.scale = SCNVector3(0.3, 0.3, 0.3)
        textNode.position = SCNVector3(0, 0.08, 0)
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        textNode.constraints = [billboard]
        pinNode.addChildNode(textNode)

        sceneView.scene.rootNode.addChildNode(pinNode)
    }
}

// MARK: - AR View

struct ItemDetectionARView: UIViewRepresentable {
    @ObservedObject var vm: ItemDetectionViewModel
    let roomId: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(vm: vm, roomId: roomId)
    }

    func makeUIView(context: Context) -> ARSCNView {
        let sceneView = ARSCNView()
        sceneView.delegate = context.coordinator
        sceneView.autoenablesDefaultLighting = true
        context.coordinator.sceneView = sceneView

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        sceneView.session.run(config)

        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleTap(_:)))
        sceneView.addGestureRecognizer(tap)
        return sceneView
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}

    // MARK: Coordinator

    final class Coordinator: NSObject, ARSCNViewDelegate {
        weak var sceneView: ARSCNView?
        let vm: ItemDetectionViewModel
        let roomId: Int

        private var planeNodes: [ARAnchor: SCNNode] = [:]

        init(vm: ItemDetectionViewModel, roomId: Int) {
            self.vm = vm
            self.roomId = roomId
        }

        // Plane visualisation
        func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
            guard let plane = anchor as? ARPlaneAnchor else { return }
            let geo = SCNPlane(width: CGFloat(plane.planeExtent.width),
                               height: CGFloat(plane.planeExtent.height))
            geo.firstMaterial?.diffuse.contents = UIColor.systemBlue.withAlphaComponent(0.08)
            geo.firstMaterial?.isDoubleSided = true
            let planeNode = SCNNode(geometry: geo)
            planeNode.simdPosition = plane.center
            planeNode.eulerAngles.x = -.pi / 2
            node.addChildNode(planeNode)
            planeNodes[anchor] = planeNode
        }

        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            guard let plane = anchor as? ARPlaneAnchor,
                  let geo = planeNodes[anchor]?.childNodes.first?.geometry as? SCNPlane else { return }
            geo.width  = CGFloat(plane.planeExtent.width)
            geo.height = CGFloat(plane.planeExtent.height)
        }

        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            guard let sceneView else { return }
            let location = sender.location(in: sceneView)

            // Raycast for world position
            let hits = sceneView.hitTest(location, types: [.existingPlaneUsingExtent, .estimatedHorizontalPlane])
            guard let hit = hits.first else { return }

            let pos: [Float] = [
                hit.worldTransform.columns.3.x,
                hit.worldTransform.columns.3.y,
                hit.worldTransform.columns.3.z,
            ]
            let normal: [Float] = [
                hit.worldTransform.columns.1.x,
                hit.worldTransform.columns.1.y,
                hit.worldTransform.columns.1.z,
            ]

            // Capture current AR camera frame
            guard let frame = sceneView.session.currentFrame else { return }
            guard let imageData = captureFrame(frame) else { return }

            Task { @MainActor [weak self] in
                guard let self, !self.vm.isAnalyzing else { return }
                await self.vm.detect(roomId: roomId, imageData: imageData, pos: pos, normal: normal, sceneView: sceneView)
            }
        }

        private func captureFrame(_ frame: ARFrame) -> Data? {
            let ciImage = CIImage(cvPixelBuffer: frame.capturedImage)
            let context = CIContext()
            guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
            // ARKit delivers the buffer in landscape; rotate to portrait
            let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
            return uiImage.jpegData(compressionQuality: 0.75)
        }
    }
}
