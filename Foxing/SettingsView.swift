import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var purchases: PurchaseManager

    @AppStorage("defaultNetTermsDays") private var defaultNetTermsDays: Int = 30
    @State private var showPaywall = false

    private let netTermsOptions = [7, 14, 15, 30, 45, 60]

    var body: some View {
        NavigationStack {
            Form {
                Section("Invoice Preferences") {
                    Text("Default Payment Terms")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("Default Payment Terms", selection: $defaultNetTermsDays) {
                        ForEach(netTermsOptions, id: \.self) { days in
                            Text("Net \(days)").tag(days)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("netTermsPicker")

                    HStack {
                        Text("Free Tier Limit")
                        Spacer()
                        Text("\(Store.freeActiveLimit) active invoices")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Active Invoices In Use")
                        Spacer()
                        Text("\(store.activeCount) / \(purchases.isPro ? "Unlimited" : "\(Store.freeActiveLimit)")")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Pro") {
                    if purchases.isPro {
                        Label("Foxing Pro Unlocked", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(FoxingPalette.inkBright)
                    } else {
                        Button("Unlock Foxing Pro") {
                            showPaywall = true
                        }
                        .accessibilityIdentifier("settingsUnlockProButton")
                    }

                    Button("Restore Purchases") {
                        Task { await purchases.restorePurchases() }
                    }
                    .accessibilityIdentifier("restorePurchasesButtonSettings")
                }

                Section("About") {
                    Link("Privacy Policy", destination: URL(string: "https://shimondeitel.github.io/foxing-site/privacy.html")!)
                        .accessibilityIdentifier("privacyPolicyLink")

                    Link("Contact Support", destination: URL(string: "mailto:s0533495227@gmail.com")!)
                        .accessibilityIdentifier("contactSupportLink")

                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersionString)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .dismissKeyboardOnTap()
            .navigationTitle("Settings")
            .sheet(isPresented: $showPaywall) {
                PaywallView()
                    .environmentObject(purchases)
            }
        }
    }

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
