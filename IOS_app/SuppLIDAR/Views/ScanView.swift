import SwiftUI
import ARKit
import SceneKit

/// Room scanning view. Uses RoomPlan on LiDAR-equipped devices,
/// falls back to a placeholder box export on non-LiDAR devices.
struct ScanView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var roomName = ""
    @State private var isScanning = false
    @State private var isSaving = false
    @State private var capturedFileURL: URL?
    @State private var errorMessage = ""

    private var hasLiDAR: Bool {
        ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if !isScanning {
                    setupView
                } else {
                    scanningView
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
    }

    private var setupView: some View {
        VStack(spacing: 24) {
            Image(systemName: hasLiDAR ? "cube.fill" : "cube")
                .font(.system(size: 64))
                .foregroundColor(hasLiDAR ? .blue : .secondary)

            VStack(spacing: 8) {
                Text(hasLiDAR ? "LiDAR Scan" : "Standard Scan")
                    .font(.title2.bold())
                Text(hasLiDAR
                    ? "Your device supports high-accuracy LiDAR scanning."
                    : "LiDAR not available. A placeholder room model will be created.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
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

    private var scanningView: some View {
        VStack(spacing: 16) {
            if hasLiDAR {
                RoomPlanScanView(onComplete: { url in
                    capturedFileURL = url
                    isScanning = false
                })
                .ignoresSafeArea()
            } else {
                Spacer()
                ProgressView("Creating placeholder room...")
                Spacer()
            }
        }
    }

    private func startScan() {
        if hasLiDAR {
            isScanning = true
        } else {
            createPlaceholderRoom()
        }
    }

    private func createPlaceholderRoom() {
        isSaving = true
        Task {
            do {
                let fileURL = try exportPlaceholderUSDZ()
                let _ = try await APIClient.shared.createRoom(name: roomName, fileURL: fileURL)
                await MainActor.run { isSaving = false; dismiss() }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription; isSaving = false }
            }
        }
    }

    private func exportPlaceholderUSDZ() throws -> URL {
        let scene = SCNScene()
        let box = SCNBox(width: 5, height: 3, length: 5, chamferRadius: 0)
        box.firstMaterial?.diffuse.contents = UIColor.systemGray5
        let node = SCNNode(geometry: box)
        scene.rootNode.addChildNode(node)

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
    private var captureSession: RoomCaptureSession!

    override func viewDidLoad() {
        super.viewDidLoad()
        captureView = RoomCaptureView(frame: view.bounds)
        captureView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        captureView.delegate = self
        view.addSubview(captureView)

        let config = RoomCaptureSession.Configuration()
        captureView.captureSession.run(with: config)
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
    var body: some View { Text("RoomPlan not available") }
}
#endif
