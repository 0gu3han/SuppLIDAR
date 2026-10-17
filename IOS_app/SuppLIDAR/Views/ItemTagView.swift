import SwiftUI
import PhotosUI

/// Presented after placing an AR anchor. Lets the donor take/select a photo,
/// triggers OCI Vision + Gen AI auto-fill, then confirms item details.
struct ItemTagView: View {
    let anchorId: Int
    var onSave: ((SurplusItem) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var category = "other"
    @State private var status = "in_use"
    @State private var condition = "good"
    @State private var quantity = 1
    @State private var weightKg = 0.0

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoImage: UIImage?
    @State private var isAnalyzing = false
    @State private var analysisResult: PhotoAnalysisResponse?
    @State private var isSaving = false
    @State private var errorMessage = ""

    private let categories = ["medical_equipment", "furniture", "electronics", "food",
                              "clothing", "office_supplies", "tools", "other"]
    private let statuses = ["in_use", "not_in_use", "surplus"]
    private let conditions = ["new", "good", "fair", "poor"]

    var body: some View {
        NavigationView {
            Form {
                photoSection
                autoFillBanner
                detailsSection
                metaSection

                if !errorMessage.isEmpty {
                    Section { Text(errorMessage).foregroundColor(.red).font(.caption) }
                }
            }
            .navigationTitle("Tag Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save", action: save)
                        .disabled(isSaving || name.isEmpty)
                }
            }
        }
    }

    // MARK: - Sections

    private var photoSection: some View {
        Section("Photo") {
            if let img = photoImage {
                Image(uiImage: img)
                    .resizable().scaledToFit()
                    .frame(maxHeight: 200)
                    .cornerRadius(8)
            }
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label(photoImage == nil ? "Add Photo" : "Change Photo", systemImage: "camera")
            }
            .onChange(of: selectedPhoto) { newItem in
                Task { await loadAndAnalyzePhoto(newItem) }
            }
            if isAnalyzing {
                HStack {
                    ProgressView().scaleEffect(0.8)
                    Text("OCI Vision analyzing...").font(.caption).foregroundColor(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var autoFillBanner: some View {
        if analysisResult != nil {
            Section {
                Label("Auto-filled by OCI Vision + Gen AI", systemImage: "sparkles")
                    .font(.caption).foregroundColor(.green)
            }
        }
    }

    private var detailsSection: some View {
        Section("Item Details") {
            TextField("Name", text: $name)
            TextField("Description", text: $description, axis: .vertical)
                .lineLimit(3...5)
            Picker("Category", selection: $category) {
                ForEach(categories, id: \.self) { c in
                    Text(c.replacingOccurrences(of: "_", with: " ").capitalized).tag(c)
                }
            }
            Picker("Condition", selection: $condition) {
                ForEach(conditions, id: \.self) { c in
                    Text(c.capitalized).tag(c)
                }
            }
        }
    }

    private var metaSection: some View {
        Section("Availability") {
            Picker("Status", selection: $status) {
                ForEach(statuses, id: \.self) { s in
                    Text(s.replacingOccurrences(of: "_", with: " ").capitalized).tag(s)
                }
            }
            Stepper("Quantity: \(quantity)", value: $quantity, in: 1...999)
            HStack {
                Text("Weight (kg)")
                Spacer()
                TextField("0.0", value: $weightKg, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }
        }
    }

    // MARK: - Actions

    private func loadAndAnalyzePhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else { return }

        await MainActor.run {
            photoImage = uiImage
            isAnalyzing = true
            errorMessage = ""
        }

        // First create a placeholder item to get an ID, then upload photo
        do {
            let itemId = try await APIClient.shared.createItem(
                anchorId: anchorId,
                name: "", description: "", category: "", status: status,
                condition: condition, quantity: quantity, weightKg: weightKg
            )
            let jpegData = uiImage.jpegData(compressionQuality: 0.8) ?? data
            let analysis = try await APIClient.shared.uploadItemPhoto(itemId: itemId, imageData: jpegData)

            await MainActor.run {
                analysisResult = analysis
                if name.isEmpty, let n = analysis.structured.name, !n.isEmpty { name = n }
                if description.isEmpty, let d = analysis.structured.description, !d.isEmpty { description = d }
                if let c = analysis.structured.category, !c.isEmpty { category = c }
                if let cond = analysis.structured.condition, !cond.isEmpty { condition = cond }
                isAnalyzing = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isAnalyzing = false
            }
        }
    }

    private func save() {
        isSaving = true
        Task {
            do {
                // If we already created the item during photo analysis, just update it
                if let existing = analysisResult?.item {
                    let updated = try await APIClient.shared.updateItemStatus(itemId: existing.id, status: status)
                    await MainActor.run { onSave?(updated); dismiss() }
                } else {
                    let itemId = try await APIClient.shared.createItem(
                        anchorId: anchorId, name: name, description: description,
                        category: category, status: status, condition: condition,
                        quantity: quantity, weightKg: weightKg
                    )
                    // Fetch the created item to return to caller
                    let items = try await APIClient.shared.listItems()
                    if let item = items.first(where: { $0.id == itemId }) {
                        await MainActor.run { onSave?(item); dismiss() }
                    } else {
                        await MainActor.run { dismiss() }
                    }
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription; isSaving = false }
            }
        }
    }
}
