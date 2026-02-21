import XCTest
import AVFoundation
import Combine
@testable import _024_MacC_M4_6princess

private enum StubCaptureError: Error {
    case failed
}

private final class StubCameraManager: CameraManager {
    var takePictureCalledCount = 0
    private let photoPublisher: AnyPublisher<AVCapturePhoto, Error>

    init(publisher: AnyPublisher<AVCapturePhoto, Error>) {
        self.photoPublisher = publisher

        super.init(session: AVCaptureSession(), videoDeviceInput: nil, output: AVCapturePhotoOutput(), sessionService: CameraSessionService())
    }

    override func takePicture() -> AnyPublisher<AVCapturePhoto, Error> {
        takePictureCalledCount += 1
        return photoPublisher
    }
}

private final class FailingCameraSessionService: CameraSessionServicing {
    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0

    func requestVideoAuthorization(completion: @escaping (CameraAuthorizationState) -> Void) {
        completion(.authorized)
    }

    func startSession(_ session: AVCaptureSession) {
        startCallCount += 1
    }

    func stopSession(_ session: AVCaptureSession) {
        stopCallCount += 1
    }
}

final class CameraViewModelTests: XCTestCase {
    func testTakePicBlocksConcurrentRequests() {
        let subject = PassthroughSubject<AVCapturePhoto, Error>()
        let manager = StubCameraManager(publisher: subject.eraseToAnyPublisher())
        manager.session.startRunning()

        let sut = CameraViewModel(cameraManager: manager)
        let didBegin = sut.beginCapture()
        XCTAssertTrue(didBegin)

        sut.takePic()
        sut.takePic()

        let exp = expectation(description: "takePictureCalledOnce")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            XCTAssertEqual(manager.takePictureCalledCount, 1)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2)

        subject.send(completion: .failure(StubCaptureError.failed))
    }

    func testBeginCaptureBlocksDuringCapturingState() {
        let subject = PassthroughSubject<AVCapturePhoto, Error>()
        let manager = StubCameraManager(publisher: subject.eraseToAnyPublisher())
        manager.session.startRunning()

        let sut = CameraViewModel(cameraManager: manager)
        let firstBegin = sut.beginCapture()
        XCTAssertTrue(firstBegin)

        sut.takePic()
        XCTAssertFalse(sut.beginCapture())

        subject.send(completion: .failure(StubCaptureError.failed))
    }

    func testFailureResetsCaptureStateForRetry() {
        let subject = PassthroughSubject<AVCapturePhoto, Error>()
        let manager = StubCameraManager(publisher: subject.eraseToAnyPublisher())
        manager.session.startRunning()

        let sut = CameraViewModel(cameraManager: manager)
        let exp = expectation(description: "captureFailed")

        let cancellable = sut.$captureState.sink { state in
            if state == .failed {
                exp.fulfill()
            }
        }

        XCTAssertTrue(sut.beginCapture())
        sut.takePic()

        subject.send(completion: .failure(StubCaptureError.failed))

        wait(for: [exp], timeout: 1)
        XCTAssertEqual(sut.captureState, .failed)

        sut.resetCaptureState()
        XCTAssertEqual(sut.captureState, .idle)

        cancellable.cancel()
    }

    func testCancelCaptureIfNeededResetsState() {
        let manager = StubCameraManager(publisher: Empty<AVCapturePhoto, Error>().eraseToAnyPublisher())
        manager.session.startRunning()

        let sut = CameraViewModel(cameraManager: manager)
        sut.beginCapture()
        sut.takePic()

        sut.cancelCaptureIfNeeded()
        XCTAssertEqual(sut.captureState, .cancelled)
        XCTAssertFalse(sut.isTakenPhoto)
        XCTAssertFalse(sut.routeToResult)
        XCTAssertFalse(sut.isResultNavigationInProgress)
    }
}
