import XCTest

final class SalonUITests: XCTestCase {

    @MainActor
    func testSalonHasFourWorkingRoutesAndNoVerticalScroll() {

        let app = XCUIApplication()
        app.launchArguments = ["--ui-test"]
        app.launch()

        XCTAssertTrue(
            app.buttons["Bibliothek"].firstMatch.waitForExistence(timeout: 15)
        )

        XCTAssertTrue(app.buttons["Lesen"].firstMatch.exists)
        XCTAssertTrue(app.buttons["Hören"].firstMatch.exists)
        XCTAssertTrue(app.buttons["Importieren"].firstMatch.exists)

        XCTAssertEqual(
            app.scrollViews.count,
            0,
            "Der Startsalon darf nicht vertikal scrollen."
        )

        capture(app, "01-Startsalon")

        testRoute(app, button: "Bibliothek", roomTitle: "BIBLIOTHEK")
        testRoute(app, button: "Lesen", roomTitle: "LESEN")
        testRoute(app, button: "Hören", roomTitle: "HÖREN")
        testRoute(app, button: "Importieren", roomTitle: "IMPORTIEREN")
    }

    @MainActor
    private func testRoute(_ app: XCUIApplication, button: String, roomTitle: String) {
        let routeButton = app.buttons[button].firstMatch
        XCTAssertTrue(routeButton.waitForExistence(timeout: 5), "\(button) wurde auf dem Startbildschirm nicht gefunden.")
        routeButton.tap()

        let room = app.staticTexts[roomTitle].firstMatch
        XCTAssertTrue(room.waitForExistence(timeout: 5), "Die Sackgasse \(roomTitle) wurde nicht geöffnet.")

        let backButton = app.buttons["Zurück"].firstMatch
        XCTAssertTrue(backButton.waitForExistence(timeout: 5), "Der Zurück-Button fehlt in \(roomTitle).")

        capture(app, roomTitle)

        backButton.tap()

        XCTAssertTrue(app.buttons["Bibliothek"].firstMatch.waitForExistence(timeout: 5), "Die Rückkehr zum Startsalon ist fehlgeschlagen.")
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
