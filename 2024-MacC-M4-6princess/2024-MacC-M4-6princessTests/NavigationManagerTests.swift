import XCTest
@testable import _024_MacC_M4_6princess

final class NavigationManagerTests: XCTestCase {
    @MainActor
    func testPopOnEmptyRouteDoesNothing() {
        let sut = NavigationManager()

        sut.pop()

        XCTAssertTrue(sut.route.isEmpty)
        XCTAssertEqual(sut.route.count, 0)
    }

    @MainActor
    func testPopDepthOutOfRangeDoesNothing() {
        let sut = NavigationManager()
        sut.push(screen: Screen.frameEdit)

        sut.pop(depth: 3)

        XCTAssertEqual(sut.route.count, 1)
    }

    @MainActor
    func testPopToRootClearsRoute() {
        let sut = NavigationManager()
        sut.push(screen: Screen.frameEdit)
        sut.push(screen: Screen.modifyFrame)

        sut.popToRoot()

        XCTAssertTrue(sut.route.isEmpty)
    }
}
