import XCTest
@testable import _024_MacC_M4_6princess

final class CameraDisplayPolicyTests: XCTestCase {
    func testDefaultPolicyKeeps3x4Ratio() {
        let policy = CameraDisplayPolicyStore.current
        XCTAssertEqual(policy.aspect, .ratio3x4)
        XCTAssertEqual(policy.aspectSpec.ratio, 4.0 / 3.0, accuracy: 0.0001)
    }

    func testAspectMultiplierIsHeightOverWidth() {
        let spec = CameraAspectPreset.ratio9x16.spec
        XCTAssertEqual(spec.ratio, 16.0 / 9.0, accuracy: 0.0001)
    }

    func testPreviewModeMapsToGravity() {
        XCTAssertEqual(CameraPreviewMode.fit.videoGravity, .resizeAspect)
        XCTAssertEqual(CameraPreviewMode.fill.videoGravity, .resizeAspectFill)
    }
}
