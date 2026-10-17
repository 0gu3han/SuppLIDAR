import Foundation

// MARK: - Auth

struct LoginResponse: Codable {
    let user_id: Int
    let org_id: Int
    let org_type: String
    let org_name: String
    let email: String
}

// MARK: - Rooms

struct Room: Codable, Identifiable {
    let id: Int
    let name: String
    let scan_url: String
    let created_at: String
}

struct CreateRoomResponse: Codable {
    let room_id: Int
    let name: String
    let scan_url: String
}

// MARK: - Anchors

struct Anchor: Codable, Identifiable {
    let id: Int
    let room_id: Int
    let label: String
    let pos: [Float]
    let normal: [Float]
    let items: [SurplusItem]
}

struct CreateAnchorResponse: Codable {
    let anchor_id: Int
}

// MARK: - Items

struct SurplusItem: Codable, Identifiable {
    let id: Int
    let anchor_id: Int
    let name: String
    let description: String
    let category: String
    let status: String          // in_use | not_in_use | surplus | claimed | transferred
    let condition: String       // new | good | fair | poor
    let quantity: Int
    let weight_kg: Double
    let photo_url: String
    let created_at: String
    let updated_at: String?

    var statusColor: String {
        switch status {
        case "surplus":
            return "green"
        case "claimed":
            return "orange"
        case "transferred":
            return "gray"
        case "in_use":
            return "red"
        default:
            return "yellow"
        }
    }
}

struct CreateItemResponse: Codable {
    let item_id: Int
}

struct PhotoAnalysisResponse: Codable {
    let item: SurplusItem
    let vision: VisionResult
    let structured: StructuredItem
}

struct VisionResult: Codable {
    let labels: [VisionLabel]
    let objects: [VisionLabel]
    let text: [String]
}

struct VisionLabel: Codable {
    let name: String
    let confidence: Double
}

struct StructuredItem: Codable {
    let name: String?
    let category: String?
    let condition: String?
    let description: String?
}

// MARK: - Search

struct SearchResult: Codable, Identifiable {
    var id: Int { item.id }
    let item: SurplusItem
    let score: Double
}

// MARK: - Claims

struct Claim: Codable, Identifiable {
    let id: Int
    let item_id: Int
    let nonprofit_org_id: Int
    let status: String          // pending | approved | fulfilled | rejected
    let notes: String
    let requested_at: String
    let fulfilled_at: String?
}

struct CreateClaimResponse: Codable {
    let claim_id: Int
}

// MARK: - Impact

struct ImpactReport: Codable {
    let org_name: String
    let period: String
    let items_transferred: Int
    let weight_kg: Double
    let categories: [String]
    let recipient_orgs: [String]
    let report: String
}

// MARK: - Errors

enum APIError: LocalizedError {
    case badURL
    case server(String)
    case decode(Error)

    var errorDescription: String? {
        switch self {
        case .badURL:
            return "Invalid URL"
        case .server(let m):
            return m
        case .decode(let e):
            return "Decode error: \(e.localizedDescription)"
        }
    }
}