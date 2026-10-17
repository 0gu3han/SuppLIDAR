import SwiftUI

final class AppState: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var userEmail: String = ""
    @Published var orgName: String = ""
    @Published var orgType: String = ""   // "donor" | "nonprofit" — stored locally

    init() {
        if let uid = APIClient.shared.userId, uid > 0 {
            isLoggedIn = true
            userEmail = UserDefaults.standard.string(forKey: "userEmail") ?? ""
            orgName   = UserDefaults.standard.string(forKey: "orgName")   ?? ""
            orgType   = UserDefaults.standard.string(forKey: "orgType")   ?? "donor"
        }
    }

    var isDonor: Bool { orgType == "donor" }

    /// Called after register or login. org_type / org_name come from the local
    /// registration form since Organization model is not yet in the backend.
    func login(userId: Int, email: String, orgName: String = "", orgType: String = "donor") {
        APIClient.shared.userId = userId
        UserDefaults.standard.set(email,   forKey: "userEmail")
        UserDefaults.standard.set(orgName, forKey: "orgName")
        UserDefaults.standard.set(orgType, forKey: "orgType")
        userEmail    = email
        self.orgName = orgName
        self.orgType = orgType
        isLoggedIn   = true
    }

    func logout() {
        APIClient.shared.userId = nil
        APIClient.shared.orgId  = nil
        for key in ["userEmail", "orgName", "orgType"] {
            UserDefaults.standard.removeObject(forKey: key)
        }
        userEmail = ""
        orgName   = ""
        orgType   = ""
        isLoggedIn = false
    }
}
