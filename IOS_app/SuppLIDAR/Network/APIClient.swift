import Foundation

final class APIClient {
    static let shared = APIClient()

    var baseURL: String {
        get { UserDefaults.standard.string(forKey: "baseURL") ?? "http://localhost:5001" }
        set { UserDefaults.standard.set(newValue, forKey: "baseURL") }
    }

    var userId: Int? {
        get { UserDefaults.standard.object(forKey: "userId") as? Int }
        set { UserDefaults.standard.set(newValue, forKey: "userId") }
    }

    var orgId: Int? {
        get { UserDefaults.standard.object(forKey: "orgId") as? Int }
        set { UserDefaults.standard.set(newValue, forKey: "orgId") }
    }

    private let session = URLSession.shared
    private let decoder = JSONDecoder()
    private init() {}

    // MARK: - Auth

    struct SimpleAuthResponse: Codable {
        let user_id: Int
        let email: String
    }

    func register(email: String, name: String, orgType: String = "donor") async throws -> SimpleAuthResponse {
        var req = try makeRequest(path: "/auth/register", method: "POST")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "email": email, "name": name, "org_type": orgType
        ])
        return try await send(req)
    }

    func login(email: String) async throws -> SimpleAuthResponse {
        var req = try makeRequest(path: "/auth/login", method: "POST")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["email": email])
        return try await send(req)
    }

    // MARK: - Rooms

    func listRooms() async throws -> [Room] {
        struct Wrapper: Codable { let rooms: [Room] }
        guard let uid = userId else { throw APIError.server("Not logged in") }
        let req = try makeRequest(path: "/rooms?user_id=\(uid)")
        return try await (send(req) as Wrapper).rooms
    }

    func createRoom(name: String, fileURL: URL) async throws -> CreateRoomResponse {
        guard let uid = userId else { throw APIError.server("Not logged in") }
        guard let url = URL(string: "\(baseURL)/rooms") else { throw APIError.badURL }
        let boundary = UUID().uuidString
        var req = URLRequest(url: url, timeoutInterval: 300)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        let body = try buildMultipart(boundary: boundary, fields: [
            ("user_id", "\(uid)"), ("name", name)
        ], fileURL: fileURL, fileField: "file")
        let (data, resp) = try await session.upload(for: req, from: body)
        try checkStatus(data: data, response: resp)
        return try decoder.decode(CreateRoomResponse.self, from: data)
    }

    func deleteRoom(roomId: Int) async throws {
        let req = try makeRequest(path: "/rooms/\(roomId)", method: "DELETE")
        _ = try await session.data(for: req)
    }

    // MARK: - Anchors

    func listAnchors(roomId: Int) async throws -> [Anchor] {
        struct Wrapper: Codable { let anchors: [Anchor] }
        let req = try makeRequest(path: "/anchors?room_id=\(roomId)")
        return try await (send(req) as Wrapper).anchors
    }

    func createAnchor(roomId: Int, label: String, pos: [Float], normal: [Float]) async throws -> Int {
        var req = try makeRequest(path: "/anchors", method: "POST")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "room_id": roomId, "label": label, "pos": pos, "normal": normal
        ])
        let resp: CreateAnchorResponse = try await send(req)
        return resp.anchor_id
    }

    func deleteAnchor(id: Int) async throws {
        let req = try makeRequest(path: "/anchors/\(id)", method: "DELETE")
        _ = try await session.data(for: req)
    }

    // MARK: - Items

    func listItems(roomId: Int? = nil, status: String? = nil) async throws -> [SurplusItem] {
        struct Wrapper: Codable { let items: [SurplusItem] }
        var path = "/items?"
        if let rid = roomId { path += "room_id=\(rid)&" }
        if let s = status { path += "status=\(s)&" }
        if let oid = orgId { path += "org_id=\(oid)" }
        let req = try makeRequest(path: path)
        return try await (send(req) as Wrapper).items
    }

    func createItem(anchorId: Int, name: String, description: String, category: String,
                    status: String, condition: String, quantity: Int, weightKg: Double) async throws -> Int {
        var req = try makeRequest(path: "/items", method: "POST")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "anchor_id": anchorId,
            "name": name,
            "description": description,
            "category": category,
            "status": status,
            "condition": condition,
            "quantity": quantity,
            "weight_kg": weightKg,
        ])
        let resp: CreateItemResponse = try await send(req)
        return resp.item_id
    }

    func updateItemStatus(itemId: Int, status: String) async throws -> SurplusItem {
        var req = try makeRequest(path: "/items/\(itemId)", method: "PATCH")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["status": status])
        return try await send(req)
    }

    func uploadItemPhoto(itemId: Int, imageData: Data, ext: String = "jpg") async throws -> PhotoAnalysisResponse {
        guard let url = URL(string: "\(baseURL)/items/\(itemId)/photo") else { throw APIError.badURL }
        let boundary = UUID().uuidString
        var req = URLRequest(url: url, timeoutInterval: 120)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        let crlf = "\r\n"
        body.append("--\(boundary)\(crlf)".utf8Data)
        body.append("Content-Disposition: form-data; name=\"photo\"; filename=\"photo.\(ext)\"\(crlf)".utf8Data)
        body.append("Content-Type: image/\(ext)\(crlf)\(crlf)".utf8Data)
        body.append(imageData)
        body.append("\(crlf)--\(boundary)--\(crlf)".utf8Data)

        let (data, resp) = try await session.upload(for: req, from: body)
        try checkStatus(data: data, response: resp)
        return try decoder.decode(PhotoAnalysisResponse.self, from: data)
    }

    // MARK: - OCI Detection

    func detectPhoto(imageData: Data, ext: String = "jpg") async throws -> DetectionResult {
        guard let url = URL(string: "\(baseURL)/detect/photo") else { throw APIError.badURL }
        let boundary = UUID().uuidString
        var req = URLRequest(url: url, timeoutInterval: 60)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        let crlf = "\r\n"
        body.append("--\(boundary)\(crlf)".utf8Data)
        body.append("Content-Disposition: form-data; name=\"photo\"; filename=\"photo.\(ext)\"\(crlf)".utf8Data)
        body.append("Content-Type: image/\(ext)\(crlf)\(crlf)".utf8Data)
        body.append(imageData)
        body.append("\(crlf)--\(boundary)--\(crlf)".utf8Data)

        let (data, resp) = try await session.upload(for: req, from: body)
        try checkStatus(data: data, response: resp)
        return try decoder.decode(DetectionResult.self, from: data)
    }

    // MARK: - Objects

    func createObject(anchorId: Int, title: String, kind: String = "text", body bodyStr: String = "") async throws -> Int {
        struct Resp: Codable { let object_id: Int }
        var req = try makeRequest(path: "/objects", method: "POST")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "anchor_id": anchorId, "title": title, "kind": kind, "body": bodyStr
        ])
        return try await (send(req) as Resp).object_id
    }

    // MARK: - Search

    func searchSurplus(query: String) async throws -> [SearchResult] {
        struct Wrapper: Codable { let results: [SearchResult] }
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let req = try makeRequest(path: "/items/search?q=\(encoded)")
        return try await (send(req) as Wrapper).results
    }

    // MARK: - Claims

    func createClaim(itemId: Int, notes: String = "") async throws -> Int {
        guard let uid = userId, let oid = orgId else { throw APIError.server("Not logged in") }
        var req = try makeRequest(path: "/claims", method: "POST")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "item_id": itemId,
            "nonprofit_org_id": oid,
            "user_id": uid,
            "notes": notes,
        ])
        let resp: CreateClaimResponse = try await send(req)
        return resp.claim_id
    }

    func listClaims(role: String = "nonprofit") async throws -> [Claim] {
        struct Wrapper: Codable { let claims: [Claim] }
        let oid = orgId ?? 0
        let req = try makeRequest(path: "/claims?org_id=\(oid)&role=\(role)")
        return try await (send(req) as Wrapper).claims
    }

    func updateClaim(claimId: Int, status: String) async throws {
        var req = try makeRequest(path: "/claims/\(claimId)", method: "PATCH")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["status": status])
        _ = try await session.data(for: req)
    }

    // MARK: - Impact

    func getImpactReport(orgId: Int) async throws -> ImpactReport {
        let req = try makeRequest(path: "/impact/\(orgId)")
        return try await send(req)
    }

    // MARK: - Helpers

    private func makeRequest(path: String, method: String = "GET", timeout: TimeInterval = 30) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)\(path)") else { throw APIError.badURL }
        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return req
    }

    private func send<T: Decodable>(_ req: URLRequest) async throws -> T {
        let (data, resp) = try await session.data(for: req)
        try checkStatus(data: data, response: resp)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decode(error)
        }
    }

    private func checkStatus(data: Data, response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) else { return }
        let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
        throw APIError.server(msg ?? "HTTP \(http.statusCode)")
    }

    private func buildMultipart(boundary: String, fields: [(String, String)], fileURL: URL, fileField: String) throws -> Data {
        var body = Data()
        let crlf = "\r\n"
        for (name, value) in fields {
            body.append("--\(boundary)\(crlf)".utf8Data)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\(crlf)\(crlf)".utf8Data)
            body.append("\(value)\(crlf)".utf8Data)
        }
        let fileData = try Data(contentsOf: fileURL)
        let filename = fileURL.lastPathComponent
        let ext = fileURL.pathExtension.lowercased()
        let mime: String
        switch ext {
        case "usdz": mime = "model/vnd.usdz+zip"
        case "glb":  mime = "model/gltf-binary"
        default:     mime = "application/octet-stream"
        }
        body.append("--\(boundary)\(crlf)".utf8Data)
        body.append("Content-Disposition: form-data; name=\"\(fileField)\"; filename=\"\(filename)\"\(crlf)".utf8Data)
        body.append("Content-Type: \(mime)\(crlf)\(crlf)".utf8Data)
        body.append(fileData)
        body.append("\(crlf)--\(boundary)--\(crlf)".utf8Data)
        return body
    }
}

private extension String {
    var utf8Data: Data { Data(utf8) }
}
