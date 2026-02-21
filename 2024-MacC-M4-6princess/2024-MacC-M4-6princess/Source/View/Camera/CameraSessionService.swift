import Foundation
import AVFoundation

enum CameraAuthorizationState: Equatable {
    case authorized
    case notDetermined
    case denied
    case restricted

    static func from(_ status: AVAuthorizationStatus) -> CameraAuthorizationState {
        switch status {
        case .authorized: return .authorized
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .denied
        }
    }
}

protocol CameraSessionServicing {
    func requestVideoAuthorization(completion: @escaping (CameraAuthorizationState) -> Void)
    func startSession(_ session: AVCaptureSession)
    func stopSession(_ session: AVCaptureSession)
}

final class CameraSessionService: CameraSessionServicing {
    private let logger: (String) -> Void
    private let authorizationStatusProvider: () -> AVAuthorizationStatus
    private let requestAccessProvider: (@escaping (Bool) -> Void) -> Void

    init(
        logger: @escaping (String) -> Void = { print($0) },
        authorizationStatusProvider: @escaping () -> AVAuthorizationStatus = { AVCaptureDevice.authorizationStatus(for: .video) },
        requestAccessProvider: @escaping (@escaping (Bool) -> Void) -> Void = { completion in
            AVCaptureDevice.requestAccess(for: .video, completionHandler: completion)
        }
    ) {
        self.logger = logger
        self.authorizationStatusProvider = authorizationStatusProvider
        self.requestAccessProvider = requestAccessProvider
    }

    func requestVideoAuthorization(completion: @escaping (CameraAuthorizationState) -> Void) {
        let currentState = CameraAuthorizationState.from(authorizationStatusProvider())

        switch currentState {
        case .authorized, .denied, .restricted:
            logger("[CameraSession] authorization=\(currentState)")
            completion(currentState)
        case .notDetermined:
            requestAccessProvider { granted in
                let result: CameraAuthorizationState = granted ? .authorized : .denied
                self.logger("[CameraSession] authorizationRequested result=\(result)")
                completion(result)
            }
        }
    }

    func startSession(_ session: AVCaptureSession) {
        Task {
            if !session.isRunning {
                session.startRunning()
                logger("[CameraSession] started")
            }
        }
    }

    func stopSession(_ session: AVCaptureSession) {
        Task {
            if session.isRunning {
                session.stopRunning()
                logger("[CameraSession] stopped")
            }
        }
    }
}
