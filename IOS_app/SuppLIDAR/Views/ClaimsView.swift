import SwiftUI

struct ClaimsView: View {
    let role: String   // "donor" | "nonprofit"
    @State private var claims: [Claim] = []
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading claims...")
                } else if claims.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray").font(.system(size: 50)).foregroundColor(.secondary)
                        Text("No claims yet").foregroundColor(.secondary)
                    }
                } else {
                    List(claims) { claim in
                        ClaimRowView(claim: claim, role: role, onUpdate: load)
                    }
                }
            }
            .navigationTitle(role == "donor" ? "Incoming Claims" : "My Claims")
            .onAppear(perform: load)
        }
    }

    private func load() {
        isLoading = true
        Task {
            let result = (try? await APIClient.shared.listClaims(role: role)) ?? []
            await MainActor.run { claims = result; isLoading = false }
        }
    }
}

struct ClaimRowView: View {
    let claim: Claim
    let role: String
    let onUpdate: () -> Void
    @State private var isUpdating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Item #\(claim.item_id)").font(.headline)
                Spacer()
                statusBadge
            }
            if !claim.notes.isEmpty {
                Text(claim.notes).font(.caption).foregroundColor(.secondary)
            }
            Text("Requested: \(claim.requested_at.prefix(10))").font(.caption2).foregroundColor(.secondary)

            if role == "donor" && claim.status == "pending" {
                HStack(spacing: 12) {
                    Button("Approve") { update("approved") }
                        .buttonStyle(.borderedProminent).controlSize(.small)
                    Button("Reject") { update("rejected") }
                        .buttonStyle(.bordered).controlSize(.small).tint(.red)
                }
                .disabled(isUpdating)
            }
            if role == "donor" && claim.status == "approved" {
                Button("Mark Fulfilled") { update("fulfilled") }
                    .buttonStyle(.borderedProminent).controlSize(.small).tint(.green)
                    .disabled(isUpdating)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusBadge: some View {
        let color: Color = {
            switch claim.status {
            case "approved":  return .blue
            case "fulfilled": return .green
            case "rejected":  return .red
            default:          return .orange
            }
        }()
        return Text(claim.status.capitalized)
            .font(.caption2)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(color.opacity(0.15)).foregroundColor(color).cornerRadius(4)
    }

    private func update(_ status: String) {
        isUpdating = true
        Task {
            try? await APIClient.shared.updateClaim(claimId: claim.id, status: status)
            await MainActor.run { isUpdating = false; onUpdate() }
        }
    }
}
