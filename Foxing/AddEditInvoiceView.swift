import SwiftUI

struct AddEditInvoiceView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var purchases: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    let existing: Invoice?

    @State private var clientName: String = ""
    @State private var amountText: String = ""
    @State private var dateSent: Date = Date()
    @State private var dueDate: Date = Date().addingTimeInterval(60 * 60 * 24 * 30)
    @State private var notes: String = ""
    @State private var showValidationError = false

    init(existing: Invoice?) {
        self.existing = existing
        if let existing {
            _clientName = State(initialValue: existing.clientName)
            _amountText = State(initialValue: String(format: "%.2f", existing.amount))
            _dateSent = State(initialValue: existing.dateSent)
            _dueDate = State(initialValue: existing.dueDate)
            _notes = State(initialValue: existing.notes ?? "")
        } else {
            let defaultNetDays = UserDefaults.standard.integer(forKey: "defaultNetTermsDays")
            let netDays = defaultNetDays > 0 ? defaultNetDays : 30
            _dueDate = State(initialValue: Calendar.current.date(byAdding: .day, value: netDays, to: Date()) ?? Date())
        }
    }

    private var isEditing: Bool { existing != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Client") {
                    Text("Client Name").font(.caption).foregroundStyle(.secondary)
                    TextField("e.g. Acme Studio", text: $clientName)
                        .accessibilityIdentifier("clientNameField")
                }

                Section("Invoice Details") {
                    Text("Amount").font(.caption).foregroundStyle(.secondary)
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                        .accessibilityIdentifier("amountField")

                    DatePicker("Date Sent", selection: $dateSent, displayedComponents: .date)
                        .accessibilityIdentifier("dateSentPicker")
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                        .accessibilityIdentifier("dueDatePicker")
                }

                Section("Notes (Optional)") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(1...4)
                        .accessibilityIdentifier("notesField")
                }

                if showValidationError {
                    Section {
                        Text("Enter a client name and a valid amount.")
                            .foregroundStyle(FoxingPalette.stampRed)
                            .font(.caption)
                    }
                }
            }
            .dismissKeyboardOnTap()
            .navigationTitle(isEditing ? "Edit Invoice" : "New Invoice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("cancelInvoiceButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        save()
                    }
                    .accessibilityIdentifier("saveInvoiceButton")
                }
            }
        }
    }

    private func save() {
        let trimmedName = clientName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, let amount = Double(amountText), amount > 0 else {
            showValidationError = true
            return
        }
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existing {
            var updated = existing
            updated.clientName = trimmedName
            updated.amount = amount
            updated.dateSent = dateSent
            updated.dueDate = dueDate
            updated.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
            store.updateInvoice(updated)
            dismiss()
        } else {
            let added = store.addInvoice(
                clientName: trimmedName,
                amount: amount,
                dateSent: dateSent,
                dueDate: dueDate,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                isPro: purchases.isPro
            )
            if added {
                dismiss()
            } else {
                showValidationError = true
            }
        }
    }
}
