import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            if appState.isDonor {
                DonorRoomListView()
                    .tabItem { Label("Rooms", systemImage: "cube.fill") }

                ClaimsView(role: "donor")
                    .tabItem { Label("Claims", systemImage: "tray.and.arrow.down.fill") }

                ImpactView()
                    .tabItem { Label("Impact", systemImage: "leaf.fill") }
            } else {
                NonprofitView()
                    .tabItem { Label("Browse", systemImage: "magnifyingglass") }

                ClaimsView(role: "nonprofit")
                    .tabItem { Label("My Claims", systemImage: "checkmark.circle.fill") }
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}
