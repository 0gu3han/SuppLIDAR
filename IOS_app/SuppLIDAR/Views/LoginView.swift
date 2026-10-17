import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @State private var serverURL = APIClient.shared.baseURL
    @State private var email = ""
    @State private var orgName = ""
    @State private var orgType = "donor"
    @State private var isRegistering = false
    @State private var isLoading = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            Form {
                Section("Server") {
                    TextField("Server URL", text: $serverURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .onChange(of: serverURL) { APIClient.shared.baseURL = $0 }
                }

                Section("Account") {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)

                    if isRegistering {
                        TextField("Organization Name", text: $orgName)

                        Picker("Organization Type", selection: $orgType) {
                            Text("Donor (has surplus)").tag("donor")
                            Text("Nonprofit (needs items)").tag("nonprofit")
                        }
                    }
                }

                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage).foregroundColor(.red).font(.caption)
                    }
                }

                Section {
                    Button(action: submit) {
                        if isLoading {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text(isRegistering ? "Register" : "Sign In").frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isLoading || email.isEmpty || (isRegistering && orgName.isEmpty))

                    Button(isRegistering ? "Already have an account? Sign In" : "New organization? Register") {
                        isRegistering.toggle()
                        errorMessage = ""
                    }
                    .font(.footnote)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("SuppLIDAR")
        }
    }

    private func submit() {
        isLoading = true
        errorMessage = ""
        Task {
            do {
                let (userId, email): (Int, String)
                if isRegistering {
                    // Register — server only needs email for now
                    let resp = try await APIClient.shared.register(email: email)
                    userId = resp.user_id
                    email  = resp.email
                } else {
                    let resp = try await APIClient.shared.login(email: email)
                    userId = resp.user_id
                    email  = resp.email
                }
                await MainActor.run {
                    appState.login(
                        userId: userId,
                        email: email,
                        orgName: isRegistering ? orgName : (UserDefaults.standard.string(forKey: "orgName") ?? ""),
                        orgType: isRegistering ? orgType : (UserDefaults.standard.string(forKey: "orgType") ?? "donor")
                    )
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}
