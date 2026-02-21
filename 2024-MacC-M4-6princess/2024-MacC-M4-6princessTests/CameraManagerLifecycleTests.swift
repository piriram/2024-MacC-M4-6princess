import XCTest
import AVFoundation
@testable import _024_MacC_M4_6princess

final class CameraManagerLifecycleTests: XCTestCase {
    func testStartSessionDelegatesToSessionService() {
        let session = AVCaptureSession()
        let mockService = MockCameraSessionService()
        let sut = CameraManager(session: session, sessionService: mockService)

        sut.startSession()

        XCTAssertEqual(mockService.startCallCount, 1)
        XCTAssertTrue(mockService.startedSessions.contains(where: { $0 === session }))
    }

    func testStopSessionDelegatesToSessionService() {
        let session = AVCaptureSession()
        let mockService = MockCameraSessionService()
        let sut = CameraManager(session: session, sessionService: mockService)

        sut.stopSession()

        XCTAssertEqual(mockService.stopCallCount, 1)
        XCTAssertTrue(mockService.stoppedSessions.contains(where: { $0 === session }))
    }
}

private final class MockCameraSessionService: CameraSessionServicing {
    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0
    private(set) var startedSessions: [AVCaptureSession] = []
    private(set) var stoppedSessions: [AVCaptureSession] = []

    func requestVideoAuthorization(completion: @escaping (CameraAuthorizationState) -> Void) {
        completion(.authorized)
    }

    func startSession(_ session: AVCaptureSession) {
        startCallCount += 1
        startedSessions.append(session)
    }

    func stopSession(_ session: AVCaptureSession) {
        stopCallCount += 1
        stoppedSessions.append(session)
    }
}
