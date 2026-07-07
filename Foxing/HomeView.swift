import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var purchases: PurchaseManager

    @State private var activeSheet: ActiveSheet?
    @State private var stampingInvoiceID: UUID?
    @State private var now: Date = Date()

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    if store.activeInvoices.isEmpty && store.paidInvoices.isEmpty {
                        emptyState
                    } else {
                        ForEach(store.groupedByBucket(now: now), id: \.bucket) { section in
                            bucketSection(section)
                        }

                        if !store.paidInvoices.isEmpty {
                            paidSection
                        }
                    }
                }
                .padding()
            }
            .dismissKeyboardOnTap()
            .background(FoxingPalette.paper.ignoresSafeArea())
            .navigationTitle("Foxing")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if store.isAtFreeLimit(isPro: purchases.isPro) {
                            activeSheet = .paywall
                        } else {
                            activeSheet = .addInvoice
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(FoxingPalette.ink)
                    }
                    .accessibilityIdentifier("addInvoiceButton")
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .addInvoice:
                    AddEditInvoiceView(existing: nil)
                        .environmentObject(store)
                        .environmentObject(purchases)
                case .editInvoice(let invoice):
                    AddEditInvoiceView(existing: invoice)
                        .environmentObject(store)
                        .environmentObject(purchases)
                case .paywall:
                    PaywallView()
                        .environmentObject(purchases)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 44))
                .foregroundStyle(FoxingPalette.ink.opacity(0.5))
            Text("No invoices yet")
                .font(.headline)
            Text("Tap the plus button to log your first invoice.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private func bucketSection(_ section: (bucket: AgingBucket, invoices: [Invoice])) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(section.bucket.label)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(FoxingPalette.ink)
                .accessibilityIdentifier("bucketHeader-\(section.bucket.rawValue)")

            ForEach(section.invoices) { invoice in
                invoiceCard(invoice)
            }
        }
    }

    private var paidSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Paid")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("bucketHeader-paid")

            ForEach(store.paidInvoices.sorted { ($0.paidDate ?? .distantPast) > ($1.paidDate ?? .distantPast) }) { invoice in
                paidInvoiceRow(invoice)
            }
        }
    }

    private func invoiceCard(_ invoice: Invoice) -> some View {
        let fraction = invoice.bucket(now: now).ageFraction
        let overdue = invoice.daysOverdue(now: now)

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(invoice.clientName)
                    .font(.headline)
                Spacer()
                Text(invoice.amount, format: .currency(code: "USD"))
                    .font(.headline.monospacedDigit())
            }
            HStack {
                Text("Due \(invoice.dueDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if overdue > 0 {
                    Text("\(overdue)d overdue")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(FoxingPalette.stampRed)
                }
            }
            HStack {
                Spacer()
                Button {
                    withAnimation { stampingInvoiceID = invoice.id }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                        store.markPaid(invoice)
                        stampingInvoiceID = nil
                    }
                } label: {
                    Text("Mark Paid")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(FoxingPalette.inkBright)
                .accessibilityIdentifier("markPaidButton-\(invoice.id.uuidString)")
            }
        }
        .padding(14)
        .agedPaperCard(ageFraction: fraction)
        .overlay {
            if stampingInvoiceID == invoice.id {
                PaidStampView()
                    .accessibilityIdentifier("paidStampView")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            activeSheet = .editInvoice(invoice)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                store.deleteInvoice(invoice)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .accessibilityIdentifier("deleteInvoiceButton-\(invoice.id.uuidString)")
        }
        .accessibilityIdentifier("invoiceCard-\(invoice.id.uuidString)")
    }

    private func paidInvoiceRow(_ invoice: Invoice) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(invoice.clientName)
                    .font(.subheadline)
                Text("Paid \(invoice.paidDate?.formatted(date: .abbreviated, time: .omitted) ?? "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(invoice.amount, format: .currency(code: "USD"))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemGray6))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            activeSheet = .editInvoice(invoice)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                store.deleteInvoice(invoice)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .accessibilityIdentifier("deletePaidInvoiceButton-\(invoice.id.uuidString)")
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("paidInvoiceRow-\(invoice.id.uuidString)")
    }
}
