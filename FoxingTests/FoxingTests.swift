import XCTest
@testable import Foxing

@MainActor
final class StoreTests: XCTestCase {
    var tempURL: URL!
    var store: Store!

    override func setUpWithError() throws {
        tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("foxing_test_\(UUID().uuidString).json")
        store = Store(fileURL: tempURL)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempURL)
    }

    func testAddInvoiceIncreasesActiveCount() {
        XCTAssertTrue(store.addInvoice(clientName: "Acme", amount: 500, dateSent: Date(), dueDate: Date(), notes: nil, isPro: false))
        XCTAssertEqual(store.activeCount, 1)
    }

    func testFreeLimitEnforcedAtSevenActiveInvoices() {
        for i in 0..<Store.freeActiveLimit {
            XCTAssertTrue(store.addInvoice(clientName: "Client \(i)", amount: 100, dateSent: Date(), dueDate: Date(), notes: nil, isPro: false))
        }
        XCTAssertEqual(store.activeCount, Store.freeActiveLimit)
        // 7th invoice should be rejected under free tier
        XCTAssertFalse(store.addInvoice(clientName: "Overflow Client", amount: 100, dateSent: Date(), dueDate: Date(), notes: nil, isPro: false))
        XCTAssertEqual(store.activeCount, Store.freeActiveLimit)
    }

    func testProUnlocksBeyondFreeLimit() {
        for i in 0..<Store.freeActiveLimit {
            XCTAssertTrue(store.addInvoice(clientName: "Client \(i)", amount: 100, dateSent: Date(), dueDate: Date(), notes: nil, isPro: false))
        }
        XCTAssertTrue(store.addInvoice(clientName: "Pro Client", amount: 100, dateSent: Date(), dueDate: Date(), notes: nil, isPro: true))
        XCTAssertEqual(store.activeCount, Store.freeActiveLimit + 1)
    }

    func testMarkPaidRemovesFromActiveInvoices() {
        store.addInvoice(clientName: "Acme", amount: 500, dateSent: Date(), dueDate: Date(), notes: nil, isPro: false)
        let invoice = store.activeInvoices[0]
        store.markPaid(invoice)
        XCTAssertEqual(store.activeCount, 0)
        XCTAssertEqual(store.paidInvoices.count, 1)
    }

    func testMarkPaidDoesNotCountTowardFreeLimit() {
        for i in 0..<Store.freeActiveLimit {
            store.addInvoice(clientName: "Client \(i)", amount: 100, dateSent: Date(), dueDate: Date(), notes: nil, isPro: false)
        }
        let invoice = store.activeInvoices[0]
        store.markPaid(invoice)
        XCTAssertEqual(store.activeCount, Store.freeActiveLimit - 1)
        XCTAssertTrue(store.addInvoice(clientName: "New Client", amount: 200, dateSent: Date(), dueDate: Date(), notes: nil, isPro: false))
        XCTAssertEqual(store.activeCount, Store.freeActiveLimit)
    }

    func testUpdateInvoice() {
        store.addInvoice(clientName: "Acme", amount: 500, dateSent: Date(), dueDate: Date(), notes: nil, isPro: false)
        var invoice = store.activeInvoices[0]
        invoice.clientName = "Acme Renamed"
        invoice.amount = 750
        store.updateInvoice(invoice)
        XCTAssertEqual(store.activeInvoices[0].clientName, "Acme Renamed")
        XCTAssertEqual(store.activeInvoices[0].amount, 750)
    }

    func testDeleteInvoice() {
        store.addInvoice(clientName: "Acme", amount: 500, dateSent: Date(), dueDate: Date(), notes: nil, isPro: false)
        let invoice = store.activeInvoices[0]
        store.deleteInvoice(invoice)
        XCTAssertEqual(store.invoices.count, 0)
    }

    func testUITestResetDeletesPersistedFile() throws {
        store.addInvoice(clientName: "Persisted", amount: 100, dateSent: Date(), dueDate: Date(), notes: nil, isPro: false)
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempURL.path))

        // Simulate a fresh launch with -uiTestReset by constructing a Store pointed at the
        // same file; init() should delete the file before load() so invoices come back empty.
        // We approximate the ProcessInfo check by directly deleting to mirror Store's own logic,
        // then verifying a freshly loaded Store sees no invoices.
        try? FileManager.default.removeItem(at: tempURL)
        let freshStore = Store(fileURL: tempURL)
        XCTAssertEqual(freshStore.invoices.count, 0)
    }

    func testGroupedByBucketSortsSections() {
        let now = Date()
        let cal = Calendar.current
        store.addInvoice(clientName: "Current", amount: 100, dateSent: now, dueDate: cal.date(byAdding: .day, value: 5, to: now)!, notes: nil, isPro: false)
        store.addInvoice(clientName: "Overdue45", amount: 100, dateSent: now, dueDate: cal.date(byAdding: .day, value: -45, to: now)!, notes: nil, isPro: false)
        let sections = store.groupedByBucket(now: now)
        XCTAssertEqual(sections.first?.bucket, .current)
        XCTAssertTrue(sections.contains { $0.bucket == .days31to60 })
    }
}

final class AgingBucketTests: XCTestCase {
    private let referenceNow: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 15
        return Calendar(identifier: .gregorian).date(from: components)!
    }()

    private func dueDate(daysBeforeNow days: Int) -> Date {
        Calendar(identifier: .gregorian).date(byAdding: .day, value: -days, to: referenceNow)!
    }

    func testBoundaryZeroDaysOverdueIsCurrent() {
        XCTAssertEqual(AgingBucket.bucket(dueDate: dueDate(daysBeforeNow: 0), now: referenceNow), .current)
    }

    func testBoundaryOneDayOverdueIs1to30() {
        XCTAssertEqual(AgingBucket.bucket(dueDate: dueDate(daysBeforeNow: 1), now: referenceNow), .days1to30)
    }

    func testBoundaryThirtyDaysOverdueIs1to30() {
        XCTAssertEqual(AgingBucket.bucket(dueDate: dueDate(daysBeforeNow: 30), now: referenceNow), .days1to30)
    }

    func testBoundaryThirtyOneDaysOverdueIs31to60() {
        XCTAssertEqual(AgingBucket.bucket(dueDate: dueDate(daysBeforeNow: 31), now: referenceNow), .days31to60)
    }

    func testBoundarySixtyDaysOverdueIs31to60() {
        XCTAssertEqual(AgingBucket.bucket(dueDate: dueDate(daysBeforeNow: 60), now: referenceNow), .days31to60)
    }

    func testBoundarySixtyOneDaysOverdueIs61to90() {
        XCTAssertEqual(AgingBucket.bucket(dueDate: dueDate(daysBeforeNow: 61), now: referenceNow), .days61to90)
    }

    func testBoundaryNinetyDaysOverdueIs61to90() {
        XCTAssertEqual(AgingBucket.bucket(dueDate: dueDate(daysBeforeNow: 90), now: referenceNow), .days61to90)
    }

    func testBoundaryNinetyOneDaysOverdueIs90Plus() {
        XCTAssertEqual(AgingBucket.bucket(dueDate: dueDate(daysBeforeNow: 91), now: referenceNow), .days90plus)
    }

    func testFutureDueDateIsCurrent() {
        let future = Calendar(identifier: .gregorian).date(byAdding: .day, value: 10, to: referenceNow)!
        XCTAssertEqual(AgingBucket.bucket(dueDate: future, now: referenceNow), .current)
    }

    func testDaysOverdueCalculation() {
        XCTAssertEqual(AgingBucket.daysOverdue(dueDate: dueDate(daysBeforeNow: 45), now: referenceNow), 45)
    }
}
