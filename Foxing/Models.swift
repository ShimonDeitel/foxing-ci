import Foundation

enum AgingBucket: String, CaseIterable, Codable, Identifiable {
    case current
    case days1to30
    case days31to60
    case days61to90
    case days90plus

    var id: String { rawValue }

    /// Sort order for section display: Current first, then increasing overdue.
    var sortIndex: Int {
        switch self {
        case .current: return 0
        case .days1to30: return 1
        case .days31to60: return 2
        case .days61to90: return 3
        case .days90plus: return 4
        }
    }

    /// Computes the aging bucket for a due date relative to a reference "now" date.
    /// Boundaries: daysOverdue <= 0 -> current; 1-30 -> days1to30; 31-60 -> days31to60;
    /// 61-90 -> days61to90; 91+ -> days90plus.
    static func bucket(dueDate: Date, now: Date) -> AgingBucket {
        let calendar = Calendar(identifier: .gregorian)
        let startOfDue = calendar.startOfDay(for: dueDate)
        let startOfNow = calendar.startOfDay(for: now)
        let daysOverdue = calendar.dateComponents([.day], from: startOfDue, to: startOfNow).day ?? 0

        switch daysOverdue {
        case ..<1:
            return .current
        case 1...30:
            return .days1to30
        case 31...60:
            return .days31to60
        case 61...90:
            return .days61to90
        default:
            return .days90plus
        }
    }

    static func daysOverdue(dueDate: Date, now: Date) -> Int {
        let calendar = Calendar(identifier: .gregorian)
        let startOfDue = calendar.startOfDay(for: dueDate)
        let startOfNow = calendar.startOfDay(for: now)
        return calendar.dateComponents([.day], from: startOfDue, to: startOfNow).day ?? 0
    }
}

struct Invoice: Identifiable, Codable, Equatable {
    var id: UUID
    var clientName: String
    var amount: Double
    var dateSent: Date
    var dueDate: Date
    var paidDate: Date?
    var notes: String?

    init(
        id: UUID = UUID(),
        clientName: String,
        amount: Double,
        dateSent: Date,
        dueDate: Date,
        paidDate: Date? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.clientName = clientName
        self.amount = amount
        self.dateSent = dateSent
        self.dueDate = dueDate
        self.paidDate = paidDate
        self.notes = notes
    }

    var isPaid: Bool { paidDate != nil }

    func bucket(now: Date) -> AgingBucket {
        AgingBucket.bucket(dueDate: dueDate, now: now)
    }

    func daysOverdue(now: Date) -> Int {
        AgingBucket.daysOverdue(dueDate: dueDate, now: now)
    }
}
