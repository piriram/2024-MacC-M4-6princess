import XCTest

final class SmokeLaunchUITests: XCTestCase {
    func testLaunchesApp() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertEqual(app.state, .runningForeground)
    }
}
