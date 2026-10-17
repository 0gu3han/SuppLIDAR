import SwiftUI
import ARKit
import SceneKit
import QuickLook

struct ScanView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var roomName = ""
    @State private var phase: Phase = .setup
    @State private var capturedURL: URL?
    @State private var uploadedRoomId: Int?
    @State private var errorMessage = ""
    @State private var showDetection = false

    enum Phase { case setup, scanning, previewing, uploading, done }

    private var hasLiDAR: Bool {
        ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    }

    var body: some View {
        NavigationView {
            Group {
                switch phase {
                case .setup:      setupView
                case .scanning:   scanningView
                case .previewing: previewView
                case .uploading:  uploadingView
                case .done:       doneView
                }
            }
            .navigationTitle("Scan Room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if phase == .setup {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showDetection, onDismiss: { dismiss() }) {
            if let roomId = uploadedRoomId {
                ItemDetectionView(roomId: roomId)
            }
        }
    }

    // MARK: - Setup

    private var setupView: some View {
        VStack(spacing: 24) {
            Image(systemName: hasLiDAR ? "cube.fill" : "cube")
                .font(.system(size: 64))
                .foregroundColor(hasLiDAR ? .blue : .secondary)

            VStack(spacing: 8) {
                Text(hasLiDAR ? "LiDAR Room Scan" : "Standard Scan").font(.title2.bold())
                Text(hasLiDAR
                    ? "Walk around the room — LiDAR will build a precise 3D model."
                    : "LiDAR not available. A placeholder 3D room will be created.")
                    .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
            }

            TextField("Room name (e.g. Storage Room B)", text: $roomName)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            if !errorMessage.isEmpty {
                Text(errorMessage).foregroundColor(.red).font(.caption)
            }

            Button("Start Scanning") { startScan() }
                .buttonStyle(.borderedProminent)
                .disabled(roomName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding()
    }

    // MARK: - Scanning

    private var scanningView: some View {
        LiDARScanView { url in
            capturedURL = url
            phase = .previewing
        }
        .ignoresSafeArea()
    }

    // MARK: - 3D Preview

    private var previewView: some View {
        VStack(spacing: 0) {
            if let url = capturedURL {
                SceneKitModelView(fileURL: url)
                    .ignoresSafeArea(edges: .top)
            }

            VStack(spacing: 12) {
                Text("3D Model Ready").font(.headline)
                Text("Review your room scan above, then upload to start tagging items.")
                    .font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)

                if !errorMessage.isEmpty {
                    Text(errorMessage).foregroundColor(.red).font(.caption)
                }

                HStack(spacing: 16) {
                    Button("Rescan") {
                        capturedURL = nil
                        phase = .scanning
                    }
                    .buttonStyle(.bordered)

                    Button("Upload & Continue") { uploadScan() }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(Color(.systemBackground))
        }
    }

    // MARK: - Uploading

    private var uploadingView: some View {
        VStack(spacing: 16) {
            ProgressView("Uploading 3D model...")
            Text("This may take a moment.").font(.caption).foregroundColor(.secondary)
        }
    }

    // MARK: - Done

    private var doneView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64)).foregroundColor(.green)

            VStack(spacing: 8) {
                Text("Room Uploaded!").font(.title2.bold())
                Text("Now walk through the room and tap items to detect and tag them with OCI Vision.")
                    .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
            }

            Button("Detect Items") { showDetection = true }
                .buttonStyle(.borderedProminent)

            Button("Skip for now") { dismiss() }
                .foregroundColor(.secondary)
        }
        .padding()
    }

    // MARK: - Actions

    private func startScan() {
        errorMessage = ""
        phase = .scanning
    }

    private func uploadScan() {
        guard let url = capturedURL else { return }
        phase = .uploading
        Task {
            do {
                let resp = try await APIClient.shared.createRoom(name: roomName, fileURL: url)
                await MainActor.run { uploadedRoomId = resp.room_id; phase = .done }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription; phase = .previewing }
            }
        }
    }

}

// MARK: - SceneKit 3D Model Viewer

struct SceneKitModelView: UIViewRepresentable {
    let fileURL: URL

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = true
        scnView.backgroundColor = UIColor.systemGray6
        scnView.antialiasingMode = .multisampling4X

        if let scene = try? SCNScene(url: fileURL, options: nil) {
            scnView.scene = scene
            scnView.pointOfView = bestCamera(for: scene)
        }
        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    private func bestCamera(for scene: SCNScene) -> SCNNode {
        let camera = SCNCamera()
        camera.fieldOfView = 60
        let node = SCNNode()
        node.camera = camera
        // Position camera to see the whole model
        let (min, max) = scene.rootNode.boundingBox
        let center = SCNVector3(
            (min.x + max.x) / 2,
            (min.y + max.y) / 2,
            (min.z + max.z) / 2
        )
        let size = max.z - min.z
        node.position = SCNVector3(center.x, center.y + Float(size) * 0.5, center.z + Float(size) * 1.5)
        node.look(at: center)
        return node
    }
}

// MARK: - ARKit LiDAR Scanner with live mesh (same approach as MENTIS)

struct LiDARScanView: UIViewControllerRepresentable {
    let onComplete: (URL) -> Void

    func makeUIViewController(context: Context) -> LiDARScanViewController {
        let vc = LiDARScanViewController()
        vc.onComplete = onComplete
        return vc
    }

    func updateUIViewController(_ uiViewController: LiDARScanViewController, context: Context) {}
}

final class LiDARScanViewController: UIViewController, ARSCNViewDelegate {
    var onComplete: ((URL) -> Void)?
    private var sceneView: ARSCNView!
    private var doneButton: UIButton!
    private var processingOverlay: UIView!
    private var isProcessing = false
    private let hasLiDAR = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        // ARSCNView — full screen, shows live LiDAR mesh triangles
        sceneView = ARSCNView(frame: .zero)
        sceneView.translatesAutoresizingMaskIntoConstraints = false
        sceneView.delegate = self
        sceneView.autoenablesDefaultLighting = true
        sceneView.automaticallyUpdatesLighting = true
        sceneView.debugOptions = [.showFeaturePoints]
        view.addSubview(sceneView)
        NSLayoutConstraint.activate([
            sceneView.topAnchor.constraint(equalTo: view.topAnchor),
            sceneView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sceneView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sceneView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // "Done Scanning" button
        doneButton = UIButton(type: .system)
        doneButton.setTitle("Done Scanning", for: .normal)
        doneButton.titleLabel?.font = .boldSystemFont(ofSize: 18)
        doneButton.setTitleColor(.white, for: .normal)
        doneButton.backgroundColor = .systemBlue
        doneButton.layer.cornerRadius = 14
        doneButton.layer.shadowColor = UIColor.black.cgColor
        doneButton.layer.shadowOpacity = 0.35
        doneButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        doneButton.addTarget(self, action: #selector(stopScan), for: .touchUpInside)
        view.addSubview(doneButton)
        NSLayoutConstraint.activate([
            doneButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            doneButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            doneButton.widthAnchor.constraint(equalToConstant: 210),
            doneButton.heightAnchor.constraint(equalToConstant: 52),
        ])

        // Processing overlay
        processingOverlay = UIView()
        processingOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.65)
        processingOverlay.translatesAutoresizingMaskIntoConstraints = false
        processingOverlay.isHidden = true
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.startAnimating()
        let msgLabel = UILabel()
        msgLabel.text = "Building 3D model…"
        msgLabel.textColor = .white
        msgLabel.font = .systemFont(ofSize: 17, weight: .medium)
        let stack = UIStackView(arrangedSubviews: [spinner, msgLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        processingOverlay.addSubview(stack)
        view.addSubview(processingOverlay)
        NSLayoutConstraint.activate([
            processingOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            processingOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            processingOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            processingOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.centerXAnchor.constraint(equalTo: processingOverlay.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: processingOverlay.centerYAnchor),
        ])

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        if hasLiDAR { config.sceneReconstruction = .mesh }
        sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }

    @objc private func stopScan() {
        guard !isProcessing else { return }
        isProcessing = true
        doneButton.isHidden = true
        processingOverlay.isHidden = false
        sceneView.session.pause()

        Task {
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(UUID().uuidString).usdz")
            do {
                if hasLiDAR {
                    // Export the live mesh scene captured by ARKit
                    try sceneView.scene.write(to: dest, options: nil, delegate: nil, progressHandler: nil)
                } else {
                    // Non-LiDAR fallback: simple box placeholder
                    let scene = SCNScene()
                    let box = SCNBox(width: 5, height: 3, length: 5, chamferRadius: 0)
                    box.firstMaterial?.diffuse.contents = UIColor.systemGray5
                    scene.rootNode.addChildNode(SCNNode(geometry: box))
                    try scene.write(to: dest, options: nil, delegate: nil, progressHandler: nil)
                }
                await MainActor.run { self.onComplete?(dest) }
            } catch {
                await MainActor.run {
                    self.processingOverlay.isHidden = true
                    self.doneButton.isHidden = false
                    self.isProcessing = false
                }
            }
        }
    }

    // MARK: - ARSCNViewDelegate — Live mesh rendering (ported from MENTIS)

    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard let mesh = anchor as? ARMeshAnchor else { return nil }
        let node = SCNNode()
        node.geometry = buildMeshGeometry(from: mesh)
        node.geometry?.firstMaterial = meshMaterial()
        return node
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let mesh = anchor as? ARMeshAnchor else { return }
        DispatchQueue.main.async {
            node.geometry = self.buildMeshGeometry(from: mesh)
            node.geometry?.firstMaterial = self.meshMaterial()
        }
    }

    private func buildMeshGeometry(from anchor: ARMeshAnchor) -> SCNGeometry {
        let g = anchor.geometry
        let vertexSource = SCNGeometrySource(
            buffer: g.vertices.buffer,
            vertexFormat: g.vertices.format,
            semantic: .vertex,
            vertexCount: g.vertices.count,
            dataOffset: g.vertices.offset,
            dataStride: g.vertices.stride
        )
        let normalSource = SCNGeometrySource(
            buffer: g.normals.buffer,
            vertexFormat: g.normals.format,
            semantic: .normal,
            vertexCount: g.normals.count,
            dataOffset: g.normals.offset,
            dataStride: g.normals.stride
        )
        let faceElement = SCNGeometryElement(
            buffer: g.faces.buffer,
            primitiveType: .triangles,
            primitiveCount: g.faces.count,
            bytesPerIndex: g.faces.bytesPerIndex
        )
        return SCNGeometry(sources: [vertexSource, normalSource], elements: [faceElement])
    }

    private func meshMaterial() -> SCNMaterial {
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor(red: 0.4, green: 0.851, blue: 0.8, alpha: 0.35)
        mat.isDoubleSided = true
        mat.lightingModel = .constant
        mat.fillMode = .lines
        return mat
    }
}
