import Foundation

/// Single unified sheet enum used with ONE `.sheet(item:)` modifier per screen,
/// to avoid the documented stacked-sheet/stacked-alert bug.
enum ActiveSheet: Identifiable {
    case addInvoice
    case editInvoice(Invoice)
    case paywall

    var id: String {
        switch self {
        case .addInvoice: return "addInvoice"
        case .editInvoice(let invoice): return "editInvoice-\(invoice.id.uuidString)"
        case .paywall: return "paywall"
        }
    }
}
