import SwiftUI
import SceneKit

/// Full-screen AR view for a donor to place item anchors in a room.
/// Tapping a surface places a pin; a sheet opens to tag the item.
struct ARPlacementHostView: View {
    let roomId: Int
    @Environment(\.dismiss) private var dismiss

    @StateObject private var vm = ARPlacementViewModel()
    @State private var pendingAnchorPos: SCNVector3?
    @State private var pendingAnchorNormal: SCNVector3?
    @State private var showTagSheet = false
    @State private var createdAnchorId: Int?

    var body: some View {
        ZStack(alignment: .bottom) {
            ARPlacementView(coordinator: vm.coordinator)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .shadow(radius: 4)
                    }
                    Spacer()
                    Text("Tap a surface to place an item pin")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                    Spacer()
                }
                .padding()
                Spacer()
            }
        }
        .onAppear { setupCoordinator() }
        .sheet(isPresented: $showTagSheet) {
            if let anchorId = createdAnchorId {
                ItemTagView(anchorId: anchorId) { item in
                    vm.coordinator.addAnchorPin(
                        at: pendingAnchorPos ?? SCNVector3Zero,
                        label: item.name,
                        status: item.status
                    )
                }
            }
        }
    }

    private func setupCoordinator() {
        vm.coordinator.onPlaneTap = { worldPos, normal in
            pendingAnchorPos = worldPos
            pendingAnchorNormal = normal
            Task {
                let anchorId = try? await APIClient.shared.createAnchor(
                    roomId: roomId,
                    label: "",
                    pos: [worldPos.x, worldPos.y, worldPos.z],
                    normal: [normal.x, normal.y, normal.z]
                )
                await MainActor.run {
                    createdAnchorId = anchorId
                    showTagSheet = anchorId != nil
                }
            }
        }
    }
}

final class ARPlacementViewModel: ObservableObject {
    let coordinator = ARSceneCoordinator()
}
