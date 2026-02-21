import XCTest
import AVFoundation
import Combine
@testable import _024_MacC_M4_6princess

final class CameraSessionServiceTests: XCTestCase {
    func testRequestAuthorizationReturnsAuthorizedWhenStatusAuthorized() {
        let sut = CameraSessionService(
            logger: { _ in },
            authorizationStatusProvider: { .authorized },
            requestAccessProvider: { _ in XCTFail("requestAccess should not be called") }
        )

        let exp = expectation(description: "authorization callback")
        sut.requestVideoAuthorization { state in
            XCTAssertEqual(state, .authorized)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1)
    }

    func testRequestAuthorizationUsesRequestAccessWhenStatusNotDetermined() {
        let sut = CameraSessionService(
            logger: { _ in },
            authorizationStatusProvider: { .notDetermined },
            requestAccessProvider: { completion in completion(true) }
        )

        let exp = expectation(description: "authorization callback")
        sut.requestVideoAuthorization { state in
            XCTAssertEqual(state, .authorized)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1)
    }

    func testRequestAuthorizationPublisherReturnsAuthorized() {
        let sut = CameraSessionService(
            logger: { _ in },
            authorizationStatusProvider: { .authorized },
            requestAccessProvider: { _ in }
        )

        let exp = expectation(description: "authorization publisher")
        _ = sut.requestVideoAuthorizationPublisher()
            .sink { state in
                XCTAssertEqual(state, .authorized)
                exp.fulfill()
            }

        wait(for: [exp], timeout: 1)
    }

    func testStartSessionPublisherPublishesSuccess() {
        let sut = CameraSessionService(logger: { _ in })
        let session = AVCaptureSession()

        let exp = expectation(description: "start publisher")
        _ = sut.startSessionPublisher(session)
            .sink { value in
                XCTAssertTrue(value)
                exp.fulfill()
            }

        wait(for: [exp], timeout: 1)
    }

    func testStopSessionPublisherPublishesSuccess() {
        let sut = CameraSessionService(logger: { _ in })
        let session = AVCaptureSession()

        let exp = expectation(description: "stop publisher")
        _ = sut.stopSessionPublisher(session)
            .sink { value in
                XCTAssertTrue(value)
                exp.fulfill()
            }

        wait(for: [exp], timeout: 1)
    }

    func testStartSessionLogsStartedMessage() {
        var logs: [String] = []
        let sut = CameraSessionService(
            logger: { logs.append($0) },
            authorizationStatusProvider: { .authorized },
            requestAccessProvider: { _ in }
        )
        let session = AVCaptureSession()

        sut.startSession(session)

        let exp = expectation(description: "start log")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(logs.contains("[CameraSession] started"))
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
    }
}
