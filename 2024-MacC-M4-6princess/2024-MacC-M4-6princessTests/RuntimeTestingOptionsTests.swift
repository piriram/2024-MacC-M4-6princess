import XCTest
@testable import _024_MacC_M4_6princess

final class RuntimeTestingOptionsTests: XCTestCase {
    func testResolvedCameraSourceFallsBackToSampleOnSimulator() {
        let resolved = RuntimeSelectionResolver.resolvedCameraSource(
            preferred: .device,
            isSimulator: true,
            isRealCameraAvailable: true
        )

        XCTAssertEqual(resolved, .sample)
    }

    func testResolvedCameraSourceFallsBackToSampleWhenCameraUnavailable() {
        let resolved = RuntimeSelectionResolver.resolvedCameraSource(
            preferred: .device,
            isSimulator: false,
            isRealCameraAvailable: false
        )

        XCTAssertEqual(resolved, .sample)
    }

    func testResolvedCameraSourceKeepsSampleChoice() {
        let resolved = RuntimeSelectionResolver.resolvedCameraSource(
            preferred: .sample,
            isSimulator: false,
            isRealCameraAvailable: true
        )

        XCTAssertEqual(resolved, .sample)
    }

    func testDefaultCutoutEngineMatchesPlatform() {
        let expected: CutoutEngineOption
        #if targetEnvironment(simulator)
        expected = .mock
        #else
        expected = .real
        #endif

        XCTAssertEqual(RuntimeSelectionResolver.defaultCutoutEngine(isSimulator: RuntimeTestingOptions.isSimulator), expected)
    }
}
