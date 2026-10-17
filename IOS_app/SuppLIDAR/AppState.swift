import SwiftUI

final class AppState: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var userEmail: String = ""
    @Published var orgName: String = ""
    @Published var orgType: String = ""   // "donor" | "nonprofit"

    init() {
        if let uid = APIClient.shared.userId, uid > 0 {
            isLoggedIn = true
            userEmail = UserDefaults.standard.string(forKey: "userEmail") ?? ""
            orgName = UserDefaults.standard.string(forKey: "orgName") ?? ""
            orgType = UserDefaults.standard.string(forKey: "orgType") ?? ""
        }
    }

    var isDonor: Bool { orgType == "donor" }

    func login(response: LoginResponse) {
        APIClient.shared.userId = response.user_id
        APIClient.shared.orgId = response.org_id
        UserDefaults.standard.set(response.email, forKey: "userEmail")
        UserDefaults.standard.set(response.org_name, forKey: "orgName")
        UserDefaults.standard.set(response.org_type, forKey: "orgType")
        userEmail = response.email
        orgName = response.org_name
        orgType = response.org_type
        isLoggedIn = true
    }

    func logout() {
        APIClient.shared.userId = nil
        APIClient.shared.orgId = nil
        for key in ["userEmail", "orgName", "orgType"] {
            UserDefaults.standard.removeObject(forKey: key)
        }
        userEmail = ""
        orgName = ""
        orgType = ""
        isLoggedIn = false
    }
}
