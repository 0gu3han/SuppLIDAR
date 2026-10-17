import SwiftUI

struct ImpactView: View {
    @EnvironmentObject var appState: AppState
    @State private var report: ImpactReport?
    @State private var isLoading = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Generating report with OCI Gen AI...")
                } else if let report {
                    reportView(report)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 60)).foregroundColor(.green)
                        Text("Impact Report").font(.title2.bold())
                        Text("Generate a summary of your organization's surplus donations and community impact.")
                            .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
                        if !errorMessage.isEmpty {
                            Text(errorMessage).foregroundColor(.red).font(.caption)
                        }
                        Button("Generate Report", action: load)
                            .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
            .navigationTitle("Impact")
            .toolbar {
                if report != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Refresh", action: load)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func reportView(_ report: ImpactReport) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                statsGrid(report)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Label("OCI Gen AI Report", systemImage: "sparkles")
                        .font(.headline)
                    Text(report.report)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)

                if !report.recipient_orgs.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Recipient Organizations").font(.headline).padding(.horizontal)
                        ForEach(report.recipient_orgs, id: \.self) { org in
                            Label(org, systemImage: "building.2").padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
    }

    private func statsGrid(_ report: ImpactReport) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(title: "Items Transferred", value: "\(report.items_transferred)", icon: "shippingbox.fill", color: .blue)
            StatCard(title: "Weight Diverted", value: "\(String(format: "%.1f", report.weight_kg)) kg", icon: "scalemass.fill", color: .green)
            StatCard(title: "Categories", value: "\(report.categories.count)", icon: "tag.fill", color: .orange)
            StatCard(title: "Partners", value: "\(report.recipient_orgs.count)", icon: "person.2.fill", color: .purple)
        }
    }

    private func load() {
        guard let orgId = APIClient.shared.orgId else { return }
        isLoading = true
        errorMessage = ""
        Task {
            do {
                let result = try await APIClient.shared.getImpactReport(orgId: orgId)
                await MainActor.run { report = result; isLoading = false }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription; isLoading = false }
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title2).foregroundColor(color)
            Text(value).font(.title3.bold())
            Text(title).font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.08))
        .cornerRadius(12)
    }
}
