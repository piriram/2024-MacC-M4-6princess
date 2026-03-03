import XCTest
@testable import _024_MacC_M4_6princess

final class AppErrorTests: XCTestCase {
    func testAllAppErrorUserMessagesAreNotEmpty() {
        let errors: [AppError] = [
            .inputImageMissing,
            .maskCreationFailed,
            .imageRenderingFailed,
            .coreDataFetchFailed,
            .coreDataSaveFailed,
            .photoLibraryPermissionDenied,
            .albumCreationFailed,
            .albumNotFound,
            .photoSaveFailed,
            .uiNotReady
        ]

        for error in errors {
            XCTAssertFalse(error.userMessage.isEmpty)
        }
    }

    @MainActor
    func testIOViewModelShowErrorSetsAlertState() {
        let sut = IOViewModel()
        let expectation = expectation(description: "showError updates alert state")

        sut.showError(.imageRenderingFailed)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            XCTAssertTrue(sut.showAlert)
            XCTAssertEqual(sut.alertMessage, AppError.imageRenderingFailed.userMessage)
            if case .imageRenderingFailed? = sut.appError {
                XCTAssertTrue(true)
            } else {
                XCTFail("Expected imageRenderingFailed error")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    @MainActor
    func testIOViewModelShowErrorWithDetailIncludesDetailText() {
        let sut = IOViewModel()
        let expectation = expectation(description: "showError includes detail")

        sut.showError(.photoSaveFailed, detail: "disk full")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            XCTAssertTrue(sut.showAlert)
            XCTAssertTrue(sut.alertMessage.contains(AppError.photoSaveFailed.userMessage))
            XCTAssertTrue(sut.alertMessage.contains("disk full"))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }
}
