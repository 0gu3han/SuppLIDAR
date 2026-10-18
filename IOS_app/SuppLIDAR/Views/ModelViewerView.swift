import SwiftUI
import SceneKit

// MARK: - Host View

struct ModelViewerView: View {
    let room: Room

    @Environment(\.dismiss) private var dismiss
    @State private var anchors: [Anchor] = []
    @State private var isLoading = true
    @State private var localFileURL: URL?
    @State private var sceneLoadFailed = false
    @State private var pendingPosition: SCNVector3?
    @State private var showAddAnchor = false
    @State private var showExport = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack(alignment: .top) {
            Color.mSurface.ignoresSafeArea()

            if isLoading {
                loadingView
            } else if sceneLoadFailed {
                failedView
            } else if let fileURL = localFileURL {
                ModelSceneView(
                    fileURL: fileURL,
                    anchors: anchors,
                    onTapped: { pos in
                        pendingPosition = pos
                        showAddAnchor = true
                    }
                )
                .ignoresSafeArea()

                VStack {
                    Spacer()
                    Text("Pinch & drag to explore · tap model to place anchor")
                        .font(.mLabel(12))
                        .tracking(0.2)
                        .foregroundStyle(Color.mOnSurface)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.mSurfaceContainerHigh.opacity(0.85), in: Capsule())
                        .padding(.bottom, 40)
                }
            }

            topBar
        }
        .statusBarHidden()
        .task { await load() }
        .sheet(isPresented: $showAddAnchor) {
            if let pos = pendingPosition {
                AddModelAnchorSheet(position: pos) { label in
                    await createAnchor(label: label, pos: pos)
                }
                .presentationDetents([.medium])
            }
        }
        .sheet(isPresented: $showExport) {
            if let url = localFileURL {
                ModelShareSheet(items: [url])
            }
        }
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Sub-views

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.mOnSurface)
            }
            Spacer()
            Text(room.name)
                .font(.mTitle(15))
                .foregroundStyle(Color.mOnSurface)
            Spacer()
            Button { showExport = true } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.mPrimary)
            }
            .opacity((localFileURL != nil && !sceneLoadFailed) ? 1 : 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.mSurfaceContainerLow.opacity(0.9))
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(Color.mPrimary)
                .scaleEffect(1.5)
            Text("Loading 3D model…")
                .font(.mLabel()).tracking(0.5)
                .foregroundStyle(Color.mSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var failedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "cube.transparent")
                .font(.system(size: 48))
                .foregroundStyle(Color.mSecondary)
            Text("No 3D model available")
                .font(.mTitle())
                .foregroundStyle(Color.mOnSurface)
            Text("No iOS preview available.\nOpen the web viewer to see your 3D model with textures.")
                .font(.mBody())
                .foregroundStyle(Color.mSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Actions

    private func load() async {
        do {
            async let file = APIClient.shared.downloadRoomFile(roomId: room.id)
            async let anchorList = APIClient.shared.listAnchors(roomId: room.id)
            let downloadedURL = try await file
            anchors = (try? await anchorList) ?? []

            // Backend converts GLB → USDZ before serving; SceneKit loads USDZ natively
            if (try? SCNScene(url: downloadedURL, options: nil)) != nil {
                localFileURL = downloadedURL
            } else {
                sceneLoadFailed = true
            }
        } catch {
            errorMessage = error.localizedDescription
            sceneLoadFailed = true
        }
        isLoading = false
    }

    private func createAnchor(label: String, pos: SCNVector3) async {
        do {
            _ = try await APIClient.shared.createAnchor(
                roomId: room.id,
                label: label,
                pos: [pos.x, pos.y, pos.z],
                normal: [0, 1, 0]
            )
            anchors = (try? await APIClient.shared.listAnchors(roomId: room.id)) ?? []
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - SceneKit UIViewRepresentable

struct ModelSceneView: UIViewRepresentable {
    let fileURL: URL
    let anchors: [Anchor]
    let onTapped: (SCNVector3) -> Void

    func makeCoordinator() -> ModelSceneCoordinator {
        ModelSceneCoordinator(onTapped: onTapped)
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false   // we add our own lights below
        view.backgroundColor = UIColor(red: 0.062, green: 0.078, blue: 0.102, alpha: 1)
        view.antialiasingMode = .multisampling4X

        // Backend serves USDZ (converted from GLB server-side); SceneKit loads it natively
        let scene = (try? SCNScene(url: fileURL, options: [
            SCNSceneSource.LoadingOption.convertToYUp: true,
            SCNSceneSource.LoadingOption.flattenScene: false,
        ])) ?? SCNScene()

        // Apply material settings: keep existing textures, add grey fallback only if no material.
        scene.rootNode.enumerateChildNodes { node, _ in
            guard let geo = node.geometry, !geo.sources.isEmpty else { return }
            if geo.materials.isEmpty {
                let mat = SCNMaterial()
                mat.diffuse.contents = UIColor(red: 0.55, green: 0.57, blue: 0.62, alpha: 1)
                mat.lightingModel    = .lambert
                mat.isDoubleSided    = true
                geo.materials        = [mat]
            } else {
                geo.materials.forEach {
                    $0.lightingModel = .lambert
                    $0.isDoubleSided = true
                }
            }
        }

        // Lighting rig
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light!.type = .ambient
        ambient.light!.intensity = 400
        ambient.light!.color = UIColor.white
        scene.rootNode.addChildNode(ambient)

        let omni = SCNNode()
        omni.light = SCNLight()
        omni.light!.type = .omni
        omni.light!.intensity = 800
        omni.position = SCNVector3(5, 8, 5)
        scene.rootNode.addChildNode(omni)

        // Auto-fit camera
        let (bMin, bMax) = scene.rootNode.boundingBox
        let cx = (bMin.x + bMax.x) / 2
        let cy = (bMin.y + bMax.y) / 2
        let cz = (bMin.z + bMax.z) / 2
        let spanX = bMax.x - bMin.x
        let spanY = bMax.y - bMin.y
        let spanZ = bMax.z - bMin.z
        let span = max(max(spanX, spanY), max(spanZ, 1.0))   // min span = 1 m

        let camNode = SCNNode()
        camNode.camera = SCNCamera()
        camNode.camera!.zNear  = Double(span) * 0.01
        camNode.camera!.zFar   = Double(span) * 20
        camNode.camera!.fieldOfView = 60
        camNode.position = SCNVector3(cx, cy + span * 0.3, cz + span * 1.4)
        camNode.look(at: SCNVector3(cx, cy, cz))
        scene.rootNode.addChildNode(camNode)

        view.scene = scene
        view.pointOfView = camNode

        context.coordinator.setup(view)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.updateAnchors(anchors, in: uiView)
    }
}

// MARK: - SceneKit Coordinator

final class ModelSceneCoordinator: NSObject {
    private let onTapped: (SCNVector3) -> Void
    private weak var sceneView: SCNView?
    private var anchorNodes: [Int: SCNNode] = [:]
    private var lastAnchorCount = -1

    init(onTapped: @escaping (SCNVector3) -> Void) {
        self.onTapped = onTapped
    }

    func setup(_ view: SCNView) {
        sceneView = view
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        view.addGestureRecognizer(tap)
    }

    func updateAnchors(_ anchors: [Anchor], in view: SCNView) {
        guard anchors.count != lastAnchorCount else { return }
        lastAnchorCount = anchors.count

        anchorNodes.values.forEach { $0.removeFromParentNode() }
        anchorNodes.removeAll()

        for anchor in anchors {
            let node = makeAnchorNode(anchor)
            node.position = SCNVector3(anchor.pos[0], anchor.pos[1], anchor.pos[2])
            view.scene?.rootNode.addChildNode(node)
            anchorNodes[anchor.id] = node
        }
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let view = sceneView else { return }
        let location = gesture.location(in: view)
        let hits = view.hitTest(location, options: [
            SCNHitTestOption.searchMode: SCNHitTestSearchMode.closest.rawValue
        ])
        guard let hit = hits.first else { return }

        var node: SCNNode? = hit.node
        while let n = node {
            if n.name?.hasPrefix("anchor_") == true { return }
            node = n.parent
        }
        DispatchQueue.main.async { self.onTapped(hit.worldCoordinates) }
    }

    private func makeAnchorNode(_ anchor: Anchor) -> SCNNode {
        let container = SCNNode()
        container.name = "anchor_\(anchor.id)"

        let sphere = SCNSphere(radius: 0.015)
        sphere.firstMaterial?.diffuse.contents  = UIColor(red: 0.4, green: 0.44, blue: 0.79, alpha: 1)
        sphere.firstMaterial?.emission.contents = UIColor(red: 0.4, green: 0.44, blue: 0.79, alpha: 0.5)
        sphere.firstMaterial?.lightingModel = .physicallyBased
        let pin = SCNNode(geometry: sphere)
        pin.name = "anchor_\(anchor.id)"
        container.addChildNode(pin)

        let label = anchor.label.isEmpty ? "•" : anchor.label
        let text = SCNText(string: label, extrusionDepth: 0.001)
        text.font = UIFont.boldSystemFont(ofSize: 1)
        text.flatness = 0.05
        text.firstMaterial?.diffuse.contents = UIColor(red: 0.875, green: 0.886, blue: 0.922, alpha: 1)

        let textNode = SCNNode(geometry: text)
        textNode.name = "anchor_\(anchor.id)"
        textNode.scale = SCNVector3(0.006, 0.006, 0.006)

        let (tMin, tMax) = textNode.boundingBox
        let textWidth = (tMax.x - tMin.x) * 0.006
        textNode.position = SCNVector3(-textWidth / 2, 0.025, 0)

        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .all
        textNode.constraints = [billboard]
        container.addChildNode(textNode)

        return container
    }
}

// MARK: - Add Anchor Sheet

private struct AddModelAnchorSheet: View {
    let position: SCNVector3
    let onSave: (String) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var label = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Label") {
                    TextField("e.g. Capital of France", text: $label)
                }
                Section {
                    Text("Position: (\(position.x, specifier: "%.2f"), \(position.y, specifier: "%.2f"), \(position.z, specifier: "%.2f")) m")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New Anchor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        isSaving = true
                        Task {
                            await onSave(label)
                            dismiss()
                        }
                    }
                    .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
    }
}

// MARK: - Share Sheet

struct ModelShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

// MARK: - Simple USDZ viewer used in DonorRoomListView

struct SceneKitModelView: UIViewRepresentable {
    let fileURL: URL

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.autoenablesDefaultLighting = true
        view.allowsCameraControl = true
        view.backgroundColor = .black
        if let scene = try? SCNScene(url: fileURL, options: nil) {
            view.scene = scene
        }
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}
}
