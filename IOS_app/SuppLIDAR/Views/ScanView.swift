import SwiftUI
import ARKit
import SceneKit

struct ScanView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var roomName = ""
    @State private var isScanning = false
    @State private var isUploading = false
    @State private var uploadedRoomId: Int?
    @State private var showDetection = false
    @State private var errorMessage = ""

    private var hasLiDAR: Bool {
        ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let roomId = uploadedRoomId {
                    // Step 3 — scan uploaded, prompt to detect items
                    readyToDetectView(roomId: roomId)
                } else if isScanning {
                    scanningView
                } else {
                    setupView
                }
            }
            .navigationTitle("Scan Room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
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
                Text(hasLiDAR ? "LiDAR Scan" : "Standard Scan").font(.title2.bold())
                Text(hasLiDAR
                    ? "Your device supports high-accuracy LiDAR scanning."
                    : "LiDAR not available. A placeholder room will be created.")
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
        VStack(spacing: 16) {
            if isUploading {
                VStack(spacing: 12) {
                    ProgressView("Uploading scan...")
                    Text("This may take a moment.").font(.caption).foregroundColor(.secondary)
                }
            } else if hasLiDAR {
                RoomPlanScanView { url in
                    isScanning = false
                    uploadScan(fileURL: url)
                }
                .ignoresSafeArea()
            } else {
                Spacer()
                ProgressView("Creating room...")
                Spacer()
            }
        }
    }

    // MARK: - Ready to detect

    private func readyToDetectView(roomId: Int) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64)).foregroundColor(.green)

            VStack(spacing: 8) {
                Text("Room Scanned!").font(.title2.bold())
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
        if hasLiDAR {
            isScanning = true
        } else {
            isScanning = true
            isUploading = true
            Task {
                do {
                    let fileURL = try exportPlaceholderUSDZ()
                    let resp = try await APIClient.shared.createRoom(name: roomName, fileURL: fileURL)
                    await MainActor.run { isUploading = false; uploadedRoomId = resp.room_id }
                } catch {
                    await MainActor.run { errorMessage = error.localizedDescription; isScanning = false; isUploading = false }
                }
            }
        }
    }

    private func uploadScan(fileURL: URL) {
        isUploading = true
        Task {
            do {
                let resp = try await APIClient.shared.createRoom(name: roomName, fileURL: fileURL)
                await MainActor.run { isUploading = false; uploadedRoomId = resp.room_id }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription; isUploading = false }
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
        captureView.captureSession.run(with: RoomCaptureSession.Configuration())
    }

    func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool { true }

    func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).usdz")
        try? processedResult.export(to: dest)
        onComplete?(dest)
    }
}
#else
struct RoomPlanScanView: View {
    let onComplete: (URL) -> Void
    var body: some View { Text("RoomPlan not available on this device") }
}
#endif
