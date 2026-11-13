import XCTest

final class ConnecticutDirectoryUITests: XCTestCase {
    @MainActor
    func testBrowseAndSearchBundledChurchWithoutLocationPermission() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let explore = app.tabBars.buttons["Explore"]
        XCTAssertTrue(explore.waitForExistence(timeout: 10))
        explore.tap()
        let browse = app.buttons["Browse church directory"]
        XCTAssertTrue(browse.waitForExistence(timeout: 5))
        browse.tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Schilo")
        let listing = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Schilo Seventh-day Adventist Church")).firstMatch
        XCTAssertTrue(listing.waitForExistence(timeout: 5))
        listing.tap()
        XCTAssertTrue(app.staticTexts["Schilo Seventh-day Adventist Church"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["977 Hope Street, Stamford, CT 06907"].exists)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "Visit church website").firstMatch.exists)
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Connecticut directory church details"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    @MainActor
    func testDirectoryFiltersCombineAndCanReset() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let explore = app.tabBars.buttons["Explore"]
        XCTAssertTrue(explore.waitForExistence(timeout: 10))
        explore.tap()
        let browse = app.buttons["Browse church directory"]
        XCTAssertTrue(browse.waitForExistence(timeout: 5))
        browse.tap()
        let state = app.buttons["directory.stateFilter"]
        XCTAssertTrue(state.waitForExistence(timeout: 5))
        state.tap()
        app.buttons["State not listed"].tap()
        XCTAssertEqual(app.staticTexts["directory.resultCount"].label, "69 of 197 congregations")
        app.buttons["directory.clearFilters"].tap()
        state.tap()
        app.buttons["Connecticut"].tap()
        XCTAssertEqual(app.staticTexts["directory.resultCount"].label, "48 of 197 congregations")
        app.buttons["directory.conferenceFilter"].tap()
        app.buttons["Southern New England Conference"].tap()
        XCTAssertEqual(app.staticTexts["directory.resultCount"].label, "33 of 197 congregations")
        app.buttons["directory.languageFilter"].tap()
        app.buttons["Spanish"].tap()
        let search = app.searchFields.firstMatch
        search.tap()
        search.typeText("Orion")
        XCTAssertEqual(app.staticTexts["directory.resultCount"].label, "1 of 197 congregations")
        search.typeText("missing")
        XCTAssertTrue(app.staticTexts["No matching listings"].waitForExistence(timeout: 5))
        app.buttons["directory.clearFilters"].tap()
        XCTAssertEqual(app.staticTexts["directory.resultCount"].label, "197 of 197 congregations")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Directory filters"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

}
