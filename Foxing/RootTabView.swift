import SwiftUI

struct RootTabView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var purchases: PurchaseManager

    var body: some View {
        TabView {
            HomeView()
                .environmentObject(store)
                .environmentObject(purchases)
                .tabItem {
                    Label("Home", systemImage: "doc.text")
                }

            SettingsView()
                .environmentObject(store)
                .environmentObject(purchases)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(FoxingPalette.ink)
    }
}
