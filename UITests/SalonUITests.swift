import XCTest

final class SalonUITests: XCTestCase {
    @MainActor func testSalonHasFourWorkingRoutesAndNoVerticalScroll() {
        let app = XCUIApplication(); app.launchArguments = ["--ui-test"]; app.launch()
        XCTAssertTrue(app.buttons["Bibliothek"].firstMatch.waitForExistence(timeout: 15))
        XCTAssertEqual(app.scrollViews.count, 0, "Der Startsalon darf nicht vertikal scrollen.")
        capture(app, "01-Salon")
        for route in ["Bibliothek", "Lesen", "Hörbücher", "Neuer Roman"] {
            app.buttons[route].firstMatch.tap()
            XCTAssertTrue(app.buttons["Zurück"].firstMatch.waitForExistence(timeout: 5))
            capture(app, route)
            app.buttons["Zurück"].firstMatch.tap()
            XCTAssertTrue(app.buttons["Bibliothek"].firstMatch.waitForExistence(timeout: 5))
        }
    }
    @MainActor func testReaderOpensRealImportedText() {
        let app = XCUIApplication(); app.launchArguments = ["--ui-test"]; app.launch()
        XCTAssertTrue(app.buttons["Lesen"].firstMatch.waitForExistence(timeout: 15))
        app.buttons["Lesen"].firstMatch.tap()
        let book = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "RomanVoice Prüfbuch")).firstMatch
        XCTAssertTrue(book.waitForExistence(timeout: 5)); book.tap()
        XCTAssertTrue(app.descendants(matching: .any)["reader.viewport"].firstMatch.waitForExistence(timeout: 10))
        capture(app, "Reader-Zielseite")
    }
    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = name; image.lifetime = .keepAlways; add(image)
    }
}
