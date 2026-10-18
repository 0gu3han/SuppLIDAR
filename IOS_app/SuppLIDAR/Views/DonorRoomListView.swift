import SwiftUI

struct DonorRoomListView: View {
    @EnvironmentObject var appState: AppState
    @State private var rooms: [Room] = []
    @State private var isLoading = false
    @State private var showScan = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading rooms...")
                } else if rooms.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "cube.transparent")
                            .font(.system(size: 60)).foregroundColor(.secondary)
                        Text("No rooms yet").font(.headline)
                        Text("Scan a room to start tagging surplus items.")
                            .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
                        Button("Scan New Room") { showScan = true }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(rooms) { room in
                            NavigationLink(destination: RoomDetailView(room: room)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(room.name).font(.headline)
                                    Text(room.created_at.prefix(10)).font(.caption).foregroundColor(.secondary)
                                }
                            }
                        }
                        .onDelete(perform: deleteRooms)
                    }
                }
            }
            .navigationTitle(appState.orgName)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showScan = true }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Logout") { appState.logout() }
                }
            }
            .fullScreenCover(isPresented: $showScan, onDismiss: load) {
                ScanView()
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        isLoading = true
        Task {
            do {
                let result = try await APIClient.shared.listRooms()
                await MainActor.run { rooms = result; isLoading = false }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription; isLoading = false }
            }
        }
    }

    private func deleteRooms(at offsets: IndexSet) {
        let toDelete = offsets.map { rooms[$0] }
        Task {
            for room in toDelete {
                try? await APIClient.shared.deleteRoom(roomId: room.id)
            }
            await MainActor.run { rooms.remove(atOffsets: offsets) }
        }
    }
}

struct RoomDetailView: View {
    let room: Room
    @State private var anchors: [Anchor] = []
    @State private var isLoading = false
    @State private var showPlacement = false
    @State private var showModel = false
    @State private var localModelURL: URL? = nil
    @State private var isLoadingModel = false

    var body: some View {
        List {
            if isLoading {
                ProgressView()
            } else if anchors.isEmpty {
                Text("No items tagged yet.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(anchors) { anchor in
                    Section(anchor.label.isEmpty ? "Anchor #\(anchor.id)" : anchor.label) {
                        ForEach(anchor.items) { item in
                            ItemRowView(item: item)
                        }
                    }
                }
            }
        }
        .navigationTitle(room.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: loadModel) {
                    if isLoadingModel {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Image(systemName: "cube.fill")
                    }
                }
                .disabled(room.scan_url.isEmpty || isLoadingModel)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showPlacement = true }) {
                    Image(systemName: "mappin.and.ellipse")
                }
            }
        }
        .sheet(isPresented: $showModel) {
            if let url = localModelURL {
                SceneKitModelView(fileURL: url)
                    .ignoresSafeArea()
                    .overlay(alignment: .topTrailing) {
                        Button("Done") { showModel = false }
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .padding()
                    }
            }
        }
        .fullScreenCover(isPresented: $showPlacement, onDismiss: load) {
            ARPlacementHostView(roomId: room.id)
        }
        .onAppear(perform: load)
    }

    private func load() {
        isLoading = true
        Task {
            let result = (try? await APIClient.shared.listAnchors(roomId: room.id)) ?? []
            await MainActor.run { anchors = result; isLoading = false }
        }
    }

    private func loadModel() {
        guard !room.scan_url.isEmpty, !isLoadingModel else { return }
        isLoadingModel = true
        Task {
            do {
                let raw = room.scan_url
                let url = raw.hasPrefix("http")
                    ? URL(string: raw)!
                    : URL(string: APIClient.shared.baseURL + raw)!
                let (tmp, _) = try await URLSession.shared.download(from: url)
                let dest = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString + ".usdz")
                try FileManager.default.moveItem(at: tmp, to: dest)
                await MainActor.run { localModelURL = dest; isLoadingModel = false; showModel = true }
            } catch {
                await MainActor.run { isLoadingModel = false }
            }
        }
    }
}

struct ItemRowView: View {
    let item: SurplusItem
    @State private var currentStatus: String
    @State private var isUpdating = false

    init(item: SurplusItem) {
        self.item = item
        _currentStatus = State(initialValue: item.status)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name.isEmpty ? "Unnamed item" : item.name).font(.subheadline)
                if !item.category.isEmpty {
                    Text(item.category).font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
            statusPicker
        }
    }

    private var statusPicker: some View {
        Menu {
            ForEach(["in_use", "not_in_use", "surplus"], id: \.self) { s in
                Button(s.replacingOccurrences(of: "_", with: " ").capitalized) {
                    updateStatus(s)
                }
            }
        } label: {
            Text(currentStatus.replacingOccurrences(of: "_", with: " ").capitalized)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.15))
                .foregroundColor(statusColor)
                .cornerRadius(6)
        }
        .disabled(isUpdating || currentStatus == "claimed" || currentStatus == "transferred")
    }

    private var statusColor: Color {
        switch currentStatus {
        case "surplus":     return .green
        case "claimed":     return .orange
        case "transferred": return .gray
        case "in_use":      return .red
        default:            return .yellow
        }
    }

    private func updateStatus(_ newStatus: String) {
        isUpdating = true
        Task {
            _ = try? await APIClient.shared.updateItemStatus(itemId: item.id, status: newStatus)
            await MainActor.run { currentStatus = newStatus; isUpdating = false }
        }
    }
}
