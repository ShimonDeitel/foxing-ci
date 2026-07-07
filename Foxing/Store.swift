import Foundation

@MainActor
final class Store: ObservableObject {
    @Published private(set) var invoices: [Invoice] = []

    /// Free-tier cap: maximum number of ACTIVE (unpaid) invoices tracked at once.
    static let freeActiveLimit = 6

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            self.fileURL = dir.appendingPathComponent("foxing_invoices.json")
        }

        if ProcessInfo.processInfo.arguments.contains("-uiTestReset") {
            try? FileManager.default.removeItem(at: self.fileURL)
        }

        load()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else {
            invoices = []
            return
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode([Invoice].self, from: data) {
            invoices = decoded
        } else {
            invoices = []
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(invoices) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: - Derived state

    var activeInvoices: [Invoice] {
        invoices.filter { !$0.isPaid }
    }

    var paidInvoices: [Invoice] {
        invoices.filter { $0.isPaid }
    }

    var activeCount: Int { activeInvoices.count }

    func isAtFreeLimit(isPro: Bool) -> Bool {
        !isPro && activeCount >= Store.freeActiveLimit
    }

    func groupedByBucket(now: Date) -> [(bucket: AgingBucket, invoices: [Invoice])] {
        let grouped = Dictionary(grouping: activeInvoices) { $0.bucket(now: now) }
        return AgingBucket.allCases
            .sorted { $0.sortIndex < $1.sortIndex }
            .compactMap { bucket in
                guard let items = grouped[bucket], !items.isEmpty else { return nil }
                let sorted = items.sorted { $0.dueDate < $1.dueDate }
                return (bucket, sorted)
            }
    }

    // MARK: - CRUD

    @discardableResult
    func addInvoice(
        clientName: String,
        amount: Double,
        dateSent: Date,
        dueDate: Date,
        notes: String?,
        isPro: Bool
    ) -> Bool {
        guard !isAtFreeLimit(isPro: isPro) else { return false }
        let invoice = Invoice(clientName: clientName, amount: amount, dateSent: dateSent, dueDate: dueDate, notes: notes)
        invoices.append(invoice)
        save()
        return true
    }

    func updateInvoice(_ invoice: Invoice) {
        guard let idx = invoices.firstIndex(where: { $0.id == invoice.id }) else { return }
        invoices[idx] = invoice
        save()
    }

    func deleteInvoice(_ invoice: Invoice) {
        invoices.removeAll { $0.id == invoice.id }
        save()
    }

    func markPaid(_ invoice: Invoice, paidDate: Date = Date()) {
        guard let idx = invoices.firstIndex(where: { $0.id == invoice.id }) else { return }
        invoices[idx].paidDate = paidDate
        save()
    }

    func markUnpaid(_ invoice: Invoice) {
        guard let idx = invoices.firstIndex(where: { $0.id == invoice.id }) else { return }
        invoices[idx].paidDate = nil
        save()
    }
}
