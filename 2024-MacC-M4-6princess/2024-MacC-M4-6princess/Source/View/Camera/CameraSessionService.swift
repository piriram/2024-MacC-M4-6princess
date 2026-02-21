import Foundation
import AVFoundation

enum CameraAuthorizationState {
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
    func requestVideoAuthorization(completion: @escaping (CameraAuthorizationState) -> Void) {
        let currentState = CameraAuthorizationState.from(AVCaptureDevice.authorizationStatus(for: .video))

        switch currentState {
        case .authorized, .denied, .restricted:
            completion(currentState)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                completion(granted ? .authorized : .denied)
            }
        }
    }

    func startSession(_ session: AVCaptureSession) {
        Task {
            if !session.isRunning {
                session.startRunning()
            }
        }
    }

    func stopSession(_ session: AVCaptureSession) {
        Task {
            if session.isRunning {
                session.stopRunning()
            }
        }
    }
}
