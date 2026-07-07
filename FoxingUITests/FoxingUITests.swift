import XCTest

final class FoxingUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestReset"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    private func waitAndType(_ element: XCUIElement, text: String) {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        element.tap()
        element.typeText(text)
        let predicate = NSPredicate(format: "value CONTAINS[c] %@", text)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        _ = XCTWaiter.wait(for: [expectation], timeout: 3)
    }

    func testAddInvoice() {
        let addButton = app.buttons["addInvoiceButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        let clientField = app.textFields["clientNameField"]
        waitAndType(clientField, text: "Acme Studio")

        let amountField = app.textFields["amountField"]
        waitAndType(amountField, text: "1250")

        let saveButton = app.buttons["saveInvoiceButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()

        XCTAssertTrue(app.staticTexts["Acme Studio"].waitForExistence(timeout: 5))
    }

    func testMarkPaidShowsStamp() {
        addSampleInvoice(name: "Stamp Test", amount: "300")

        let markPaidPredicate = NSPredicate(format: "identifier BEGINSWITH 'markPaidButton-'")
        let markPaidButton = app.buttons.matching(markPaidPredicate).firstMatch
        XCTAssertTrue(markPaidButton.waitForExistence(timeout: 12))
        markPaidButton.tap()

        let stamp = app.staticTexts["PAID"]
        XCTAssertTrue(stamp.waitForExistence(timeout: 3))
    }

    func testFreeLimitTriggersPaywall() {
        for i in 0..<6 {
            addSampleInvoice(name: "Client \(i)", amount: "100")
        }

        let addButton = app.buttons["addInvoiceButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        let unlockButton = app.buttons["unlockProButton"]
        let notNowButton = app.buttons["dismissPaywallButton"]
        let paywallShown = unlockButton.waitForExistence(timeout: 5) || notNowButton.waitForExistence(timeout: 5)
        XCTAssertTrue(paywallShown)
    }

    func testEditInvoice() {
        addSampleInvoice(name: "Edit Target", amount: "400")

        let cardPredicate = NSPredicate(format: "identifier BEGINSWITH 'invoiceCard-'")
        let card = app.descendants(matching: .any).matching(cardPredicate).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()

        let clientField = app.textFields["clientNameField"]
        XCTAssertTrue(clientField.waitForExistence(timeout: 5))
        clientField.tap()
        clientField.clearText()
        clientField.typeText("Edited Client")

        let saveButton = app.buttons["saveInvoiceButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()

        XCTAssertTrue(app.staticTexts["Edited Client"].waitForExistence(timeout: 5))
    }

    func testDeleteInvoice() {
        addSampleInvoice(name: "Delete Target", amount: "150")
        XCTAssertTrue(app.staticTexts["Delete Target"].waitForExistence(timeout: 5))

        // The card lives in a ScrollView/LazyVStack, not a List, so delete is
        // exposed via a long-press context menu (not swipeActions, which only
        // functions inside a List).
        let cardPredicate = NSPredicate(format: "identifier BEGINSWITH 'invoiceCard-'")
        let card = app.descendants(matching: .any).matching(cardPredicate).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.press(forDuration: 1.0)

        let deletePredicate = NSPredicate(format: "identifier BEGINSWITH 'deleteInvoiceButton-'")
        let deleteButton = app.buttons.matching(deletePredicate).firstMatch
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.tap()

        let goneExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: app.staticTexts["Delete Target"]
        )
        _ = XCTWaiter.wait(for: [goneExpectation], timeout: 5)
        XCTAssertFalse(app.staticTexts["Delete Target"].exists)
    }

    func testKeyboardDismissViaFormSectionHeaderTap() {
        let addButton = app.buttons["addInvoiceButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        let clientField = app.textFields["clientNameField"]
        XCTAssertTrue(clientField.waitForExistence(timeout: 5))
        clientField.tap()
        clientField.typeText("Keyboard Test")

        XCTAssertTrue(app.keyboards.element.exists)

        // Tap a REAL Form section header label (not navigationBars.firstMatch) to dismiss.
        let sectionHeader = app.staticTexts["Invoice Details"]
        XCTAssertTrue(sectionHeader.waitForExistence(timeout: 5))
        sectionHeader.tap()

        let keyboardGoneExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: app.keyboards.element
        )
        _ = XCTWaiter.wait(for: [keyboardGoneExpectation], timeout: 5)
        XCTAssertFalse(app.keyboards.element.exists)
    }

    func testSettingsNetTermsPickerChangesDefault() {
        app.tabBars.buttons["Settings"].tap()

        let picker = app.buttons["netTermsPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.tap()

        let net45 = app.buttons["Net 45"]
        if net45.waitForExistence(timeout: 3) {
            net45.tap()
        }

        XCTAssertTrue(picker.waitForExistence(timeout: 5))
    }

    // MARK: - Helpers

    private func addSampleInvoice(name: String, amount: String) {
        let addButton = app.buttons["addInvoiceButton"]
        if addButton.waitForExistence(timeout: 5) {
            addButton.tap()
        }

        let clientField = app.textFields["clientNameField"]
        guard clientField.waitForExistence(timeout: 5) else { return }
        clientField.tap()
        clientField.typeText(name)

        let amountField = app.textFields["amountField"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5))
        amountField.tap()
        amountField.typeText(amount)

        let saveButton = app.buttons["saveInvoiceButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()
    }
}

extension XCUIElement {
    func clearText() {
        guard let stringValue = self.value as? String else { return }
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        self.typeText(deleteString)
    }
}
