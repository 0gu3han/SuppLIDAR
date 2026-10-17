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
        VStack {
            if hasLiDAR {
                RoomPlanScanView { url in
                    capturedURL = url
                    phase = .previewing
                }
                .ignoresSafeArea()
            } else {
                Spacer()
                ProgressView("Building 3D room model...")
                Spacer()
            }
        }
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
        if hasLiDAR {
            phase = .scanning
        } else {
            phase = .scanning
            Task {
                do {
                    let url  = try exportPlaceholderUSDZ()
                    capturedURL = url
                    await MainActor.run { phase = .previewing }
                } catch {
                    await MainActor.run { errorMessage = error.localizedDescription; phase = .setup }
                }
            }
        }
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

    private func exportPlaceholderUSDZ() throws -> URL {
        let scene = SCNScene()
        let box = SCNBox(width: 5, height: 3, length: 5, chamferRadius: 0)
        box.firstMaterial?.diffuse.contents = UIColor.systemGray5
        scene.rootNode.addChildNode(SCNNode(geometry: box))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).usdz")
        try scene.write(to: url, options: nil, delegate: nil, progressHandler: nil)
        return url
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

// MARK: - RoomPlan wrapper (LiDAR only)

#if canImport(RoomPlan)
import RoomPlan

struct RoomPlanScanView: UIViewControllerRepresentable {
    let onComplete: (URL) -> Void

    func makeUIViewController(context: Context) -> RoomPlanViewController {
        let vc = RoomPlanViewController()
        vc.onComplete = onComplete
        return vc
    }

    func updateUIViewController(_ uiViewController: RoomPlanViewController, context: Context) {}
}

final class RoomPlanViewController: UIViewController, RoomCaptureViewDelegate {
    var onComplete: ((URL) -> Void)?
    private var captureView: RoomCaptureView!

    override func viewDidLoad() {
        super.viewDidLoad()
        captureView = RoomCaptureView(frame: view.bounds)
        captureView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        captureView.delegate = self
        view.addSubview(captureView)
        captureView.captureSession.run(configuration: RoomCaptureSession.Configuration())
    }

    func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool { true }

    func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).usdz")
        try? processedResult.export(to: dest)
        DispatchQueue.main.async { self.onComplete?(dest) }
    }
}
#else
struct RoomPlanScanView: View {
    let onComplete: (URL) -> Void
    var body: some View { Text("RoomPlan not available on this device") }
}
#endif
