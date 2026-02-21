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

        sut.showError(.imageRenderingFailed)

        XCTAssertTrue(sut.showAlert)
        XCTAssertEqual(sut.alertMessage, AppError.imageRenderingFailed.userMessage)
        if case .imageRenderingFailed? = sut.appError {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected imageRenderingFailed error")
        }
    }
}
