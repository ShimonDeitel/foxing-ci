import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var purchases: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 52))
                    .foregroundStyle(FoxingPalette.ink)
                    .padding(.top, 20)

                Text("Foxing Pro")
                    .font(.largeTitle.bold())

                Text("You've reached the free limit of \(Store.freeActiveLimit) active invoices. Unlock unlimited invoice tracking with a one-time purchase.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 12) {
                    featureRow("infinity", "Unlimited active invoices")
                    featureRow("clock.arrow.circlepath", "Full aging history retained")
                    featureRow("checkmark.seal", "One-time purchase, no subscription")
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemGray6)))
                .padding(.horizontal)

                Spacer()

                if let product = purchases.product {
                    Button {
                        Task { await purchases.purchasePro() }
                    } label: {
                        Text("Unlock Pro - \(product.displayPrice)")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(FoxingPalette.ink)
                    .accessibilityIdentifier("unlockProButton")
                } else {
                    ProgressView()
                }

                Button("Restore Purchases") {
                    Task { await purchases.restorePurchases() }
                }
                .accessibilityIdentifier("restorePurchasesButtonPaywall")

                Button("Not Now") { dismiss() }
                    .padding(.bottom)
                    .accessibilityIdentifier("dismissPaywallButton")
            }
            .padding(.horizontal)
            .onChange(of: purchases.isPro) { _, isPro in
                if isPro { dismiss() }
            }
        }
    }

    private func featureRow(_ systemImage: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(FoxingPalette.ink)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }
}
