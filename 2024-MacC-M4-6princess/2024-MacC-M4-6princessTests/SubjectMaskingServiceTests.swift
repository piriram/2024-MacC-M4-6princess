import XCTest
import CoreImage
@testable import _024_MacC_M4_6princess

final class SubjectMaskingServiceTests: XCTestCase {
    func testStubMaskKeepsInputExtent() throws {
        let sut = StubSubjectMaskingService()
        let input = CIImage(color: .white).cropped(to: CGRect(x: 0, y: 0, width: 320, height: 240))

        let mask = try sut.makeMask(from: input)

        XCTAssertEqual(mask.extent, input.extent)
    }

    func testFactoryReturnsStubOnSimulator() {
        let service = SubjectMaskingServiceFactory.makeDefault()

        #if targetEnvironment(simulator)
        XCTAssertTrue(String(describing: type(of: service)).contains("StubSubjectMaskingService"))
        #else
        XCTAssertFalse(String(describing: type(of: service)).contains("StubSubjectMaskingService"))
        #endif
    }

    func testFactoryReturnsStubWhenUseStubMaskEnvIsSet() {
        setenv("USE_STUB_MASK", "1", 1)
        defer { unsetenv("USE_STUB_MASK") }

        let service = SubjectMaskingServiceFactory.makeDefault()

        XCTAssertTrue(String(describing: type(of: service)).contains("StubSubjectMaskingService"))
    }
}
