import SwiftUI

struct NonprofitView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchQuery = ""
    @State private var searchResults: [SearchResult] = []
    @State private var allSurplus: [SurplusItem] = []
    @State private var isSearching = false
    @State private var isLoading = false
    @State private var claimedItemIds: Set<Int> = []
    @State private var errorMessage = ""

    private var displayItems: [SurplusItem] {
        searchResults.isEmpty ? allSurplus : searchResults.map { $0.item }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                searchBar

                if isLoading || isSearching {
                    Spacer()
                    ProgressView(isSearching ? "Searching..." : "Loading...")
                    Spacer()
                } else if displayItems.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "tray").font(.system(size: 50)).foregroundColor(.secondary)
                        Text(searchQuery.isEmpty ? "No surplus items available" : "No matches found")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    List(displayItems) { item in
                        SurplusItemCard(
                            item: item,
                            isClaimed: claimedItemIds.contains(item.id),
                            onClaim: { claimItem(item) }
                        )
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Browse Surplus")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Logout") { appState.logout() }
                }
            }
            .onAppear(perform: loadAll)
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
            TextField("Search by need (e.g. wheelchairs, beds...)", text: $searchQuery)
                .autocapitalization(.none)
                .submitLabel(.search)
                .onSubmit(search)
            if !searchQuery.isEmpty {
                Button(action: { searchQuery = ""; searchResults = [] }) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func loadAll() {
        isLoading = true
        Task {
            let items = (try? await APIClient.shared.listItems(status: "surplus")) ?? []
            await MainActor.run { allSurplus = items; isLoading = false }
        }
    }

    private func search() {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }
        isSearching = true
        Task {
            let results = (try? await APIClient.shared.searchSurplus(query: searchQuery)) ?? []
            await MainActor.run { searchResults = results; isSearching = false }
        }
    }

    private func claimItem(_ item: SurplusItem) {
        Task {
            if (try? await APIClient.shared.createClaim(itemId: item.id)) != nil {
                await MainActor.run {
                    claimedItemIds.insert(item.id)
                    allSurplus.removeAll { $0.id == item.id }
                    searchResults.removeAll { $0.item.id == item.id }
                }
            }
        }
    }
}

struct SurplusItemCard: View {
    let item: SurplusItem
    let isClaimed: Bool
    let onClaim: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name.isEmpty ? "Unnamed item" : item.name).font(.headline)
                    if !item.category.isEmpty {
                        Text(item.category.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                Spacer()
                conditionBadge
            }

            if !item.description.isEmpty {
                Text(item.description).font(.subheadline).foregroundColor(.secondary).lineLimit(2)
            }

            HStack {
                Label("Qty: \(item.quantity)", systemImage: "number")
                if item.weight_kg > 0 {
                    Label("\(String(format: "%.1f", item.weight_kg)) kg", systemImage: "scalemass")
                }
                Spacer()
                claimButton
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
    }

    private var conditionBadge: some View {
        Text(item.condition.isEmpty ? "unknown" : item.condition)
            .font(.caption2)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(Color.blue.opacity(0.1))
            .foregroundColor(.blue)
            .cornerRadius(4)
    }

    private var claimButton: some View {
        Button(action: onClaim) {
            Text(isClaimed ? "Claimed" : "Claim")
                .font(.caption)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(isClaimed ? Color.gray : Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
        .disabled(isClaimed)
    }
}
