//
//  CameraModel.swift
//  2024-MacC-M4-6princess
//
//  Created by 김이예은 on 10/26/24.
//

import SwiftUI
import AVFoundation
import Photos
import Combine
import AudioToolbox

protocol CameraManagerDelegate: AnyObject {
    func cameraManager(_ manager: CameraManager, didCapturePhoto photo: AVCapturePhoto)
    func cameraManager(_ manager: CameraManager, didFailWithError error: Error)
}

class CameraManager: NSObject, AVCapturePhotoCaptureDelegate {
    private(set) var sessionSetupCancellable: AnyCancellable?
    weak var delegate: CameraManagerDelegate?
    @Published var session: AVCaptureSession
    @Published var preset: AVCaptureSession.Preset
    @Published var videoDeviceInput: AVCaptureDeviceInput?
    @Published var output: AVCapturePhotoOutput
    @Published var startFactor: CGFloat = 2.0
    @Published var deviceType: AVCaptureDevice.DeviceType
    private let sessionService: CameraSessionServicing
    private let logger: (String) -> Void
    private var captureSubject: PassthroughSubject<AVCapturePhoto, Error>?
    private let stateQueue = DispatchQueue(label: "com.024-MacC-M4-6princess.CameraManager.state")
    private var isSessionConfigured = false
    private var isConfiguringSession = false
    private var shouldStartAfterConfiguration = false

    init(session: AVCaptureSession = AVCaptureSession(),
         videoDeviceInput: AVCaptureDeviceInput? = nil,
         output: AVCapturePhotoOutput = AVCapturePhotoOutput(),
         sessionService: CameraSessionServicing = CameraSessionService(),
         logger: @escaping (String) -> Void = { print($0) }) {
        self.session = session
        self.preset = .photo
        self.videoDeviceInput = videoDeviceInput
        self.output = output
        self.deviceType = .builtInWideAngleCamera
        self.sessionService = sessionService
        self.logger = logger
        super.init()
    }

    enum AuthorizationStatus {
        case authorized
        case notDetermined
        case denied
        case restricted
        
        static func fromAVAuthorizationStatus(_ status: AVAuthorizationStatus) -> AuthorizationStatus {
            switch status {
            case .authorized: return .authorized
            case .notDetermined: return .notDetermined
            case .denied: return .denied
            case .restricted: return .restricted
            @unknown default: return .denied
            }
        }
    }

    enum SetupResult {
        case success
        case failed(Error)
        case notAuthorized
    }

    enum CaptureError: Error, LocalizedError {
        case sessionNotRunning
        case captureAlreadyInProgress

        var errorDescription: String? {
            switch self {
            case .sessionNotRunning:
                return "카메라 세션이 아직 실행되지 않았습니다."
            case .captureAlreadyInProgress:
                return "이미 촬영이 진행 중입니다."
            }
        }
    }

    //카메라 접근권한 체크 함수
    func checkVideoAuthorizaion() {
        sessionSetupCancellable = sessionService.requestVideoAuthorizationPublisher()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                switch state {
                case .authorized:
                    self.setUp(startSessionAfterConfiguration: true, reason: "authorization")
                case .notDetermined:
                    break
                case .denied:
                    print("카메라 접근권한 denied")
                case .restricted:
                    print("카메라 접근권한 restricted")
                }
            }
    }

    //카메라를 처음에 세팅하는 함수
    func setUp(startSessionAfterConfiguration: Bool = true, reason: String = "manual") {
        let setupDecision = stateQueue.sync { () -> String in
            if isSessionConfigured {
                return "reuse-configured"
            }
            if isConfiguringSession {
                return "in-progress"
            }
            isConfiguringSession = true
            return "configure"
        }

        switch setupDecision {
        case "reuse-configured":
            logger("[CameraStartup] setup decision=reuse-configured reason=\(reason)")
            if startSessionAfterConfiguration {
                startSession()
            }
            return
        case "in-progress":
            if startSessionAfterConfiguration {
                stateQueue.sync {
                    self.shouldStartAfterConfiguration = true
                }
            }
            logger("[CameraStartup] setup decision=already-configuring reason=\(reason)")
            return
        default:
            logger("[CameraStartup] setup decision=configure reason=\(reason)")
        }

        sessionService.configureSession(session, reason: "manager.setup.\(reason)") { [weak self] in
            guard let self else { return }

            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [
                    .builtInUltraWideCamera,
                    .builtInWideAngleCamera
                ],
                mediaType: .video,
                position: .back
            )

            guard let device = self.getBestCamera(from: discoverySession.devices) else {
                self.logger("[CameraStartup] setup failed=no-device reason=\(reason)")
                self.finishConfiguration(success: false)
                return
            }

            self.deviceType = device.deviceType
            self.startFactor = 1.0

            if self.session.inputs.isEmpty {
                do {
                    let input = try AVCaptureDeviceInput(device: device)
                    if self.session.canAddInput(input) {
                        self.session.addInput(input)
                        self.videoDeviceInput = input
                    }
                } catch {
                    self.logger("[CameraStartup] setup failed=input-error=\(error.localizedDescription)")
                    self.finishConfiguration(success: false)
                    return
                }
            } else if let existingInput = self.session.inputs.first as? AVCaptureDeviceInput {
                self.videoDeviceInput = existingInput
                self.deviceType = existingInput.device.deviceType
            }

            if !self.session.outputs.contains(where: { $0 === self.output }),
               self.session.canAddOutput(self.output) {
                self.session.addOutput(self.output)
            }

            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = (device.deviceType == .builtInUltraWideCamera) ? 2.0 : 1.0
                device.unlockForConfiguration()
            } catch {
                self.logger("초기 줌 설정 오류: \(error)")
            }

            self.finishConfiguration(success: true)

            if startSessionAfterConfiguration || self.consumeQueuedStartRequest() {
                self.startSession()
            } else {
                self.logger("[CameraStartup] setup decision=prewarmed-not-running")
            }
        }
    }

    func prewarmSessionIfPossible() {
        let state = sessionService.currentVideoAuthorizationState()
        guard state == .authorized else {
            logger("[CameraStartup] prewarm decision=skipped authorization=\(state)")
            return
        }

        logger("[CameraStartup] prewarm decision=configure")
        setUp(startSessionAfterConfiguration: false, reason: "prewarm")
    }

    private func finishConfiguration(success: Bool) {
        stateQueue.async {
            self.isConfiguringSession = false
            if success {
                self.isSessionConfigured = true
            }
        }
    }

    private func consumeQueuedStartRequest() -> Bool {
        stateQueue.sync {
            let shouldStart = shouldStartAfterConfiguration
            shouldStartAfterConfiguration = false
            return shouldStart
        }
    }

    
    //기기의 카메라 렌즈 사양에 따라 카메라(비디오렌즈)를 선택
    func getBestCamera(from devices: [AVCaptureDevice]) -> AVCaptureDevice? {
        // 우선순위에 따라 카메라 선택
        if let dualWideCamera = devices.first(where: { $0.deviceType == .builtInDualWideCamera }) {
            return dualWideCamera
        }
        if let tripleCamera = devices.first(where: { $0.deviceType == .builtInTripleCamera }) {
            return tripleCamera
        }
        if let dualCamera = devices.first(where: { $0.deviceType == .builtInDualCamera }) {
            return dualCamera
        }
        if let ultraWideCamera = devices.first(where: { $0.deviceType == .builtInUltraWideCamera }) {
            return ultraWideCamera
        }
        if let wideAngleCamera = devices.first(where: { $0.deviceType == .builtInWideAngleCamera }) {
            return wideAngleCamera
        }
        
        // 기본 카메라 반환
        return devices.first
    }

    //카메라 전후면 전환
    func changeCamera() {
        guard let currentInput = self.session.inputs.first as? AVCaptureDeviceInput else { return }

        sessionService.configureSession(session, reason: "manager.changeCamera") { [weak self] in
            guard let self else { return }

            self.session.removeInput(currentInput)

            let newPosition: AVCaptureDevice.Position = currentInput.device.position == .front ? .back : .front

            // 후면 카메라로 전환할 때는 항상 UltraWide 카메라를 먼저 시도
            let targetDeviceType: AVCaptureDevice.DeviceType = (newPosition == .back) ? .builtInUltraWideCamera : .builtInWideAngleCamera

            guard let newDevice = AVCaptureDevice.default(targetDeviceType, for: .video, position: newPosition),
                  let newInput = try? AVCaptureDeviceInput(device: newDevice) else {
                // UltraWide 카메라가 없는 경우 WideAngle로 폴백
                guard let fallbackDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
                      let fallbackInput = try? AVCaptureDeviceInput(device: fallbackDevice) else { return }

                if self.session.canAddInput(fallbackInput) {
                    self.session.addInput(fallbackInput)
                    self.videoDeviceInput = fallbackInput
                    self.deviceType = .builtInWideAngleCamera

                    do {
                        try fallbackDevice.lockForConfiguration()
                        // WideAngle 카메라일 때는 1.0으로 설정
                        fallbackDevice.videoZoomFactor = 1.0
                        fallbackDevice.unlockForConfiguration()
                    } catch {
                        print("줌 설정 오류: \(error)")
                    }
                }
                return
            }

            if self.session.canAddInput(newInput) {
                self.session.addInput(newInput)
                self.videoDeviceInput = newInput
                self.deviceType = targetDeviceType

                do {
                    try newDevice.lockForConfiguration()
                    if newPosition == .back {
                        // UltraWide 카메라일 때는 2.0으로 설정
                        let zoomFactor = (newDevice.deviceType == .builtInUltraWideCamera) ? 2.0 : 1.0
                        newDevice.videoZoomFactor = zoomFactor
                        newDevice.ramp(toVideoZoomFactor: zoomFactor, withRate: 1.0)
                    } else {
                        newDevice.videoZoomFactor = 1.0
                    }
                    newDevice.unlockForConfiguration()
                } catch {
                    print("카메라 전환 시 줌 설정 오류: \(error)")
                }
            }
        }
    }
    
    //카메라 세션 시작
    func startSession() {
        sessionService.startSession(session)
    }
    
    //카메라 세션 멈춤
    func stopSession() {
        sessionService.stopSession(session)
    }
    
    //사진 처리를 시작하는 함수
    func takePicture() -> AnyPublisher<AVCapturePhoto, Error> {
        guard session.isRunning else {
            print("세션이 실행중이지 않습니다")
            return Fail(error: CaptureError.sessionNotRunning).eraseToAnyPublisher()
        }

        guard captureSubject == nil else {
            return Fail(error: CaptureError.captureAlreadyInProgress).eraseToAnyPublisher()
        }

        let subject = PassthroughSubject<AVCapturePhoto, Error>()
        captureSubject = subject
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        
        // 메인 스레드에서 실행
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.output.capturePhoto(with: settings, delegate: self)
        }

        return subject
            .handleEvents(receiveCancel: { [weak self] in
                self?.captureSubject = nil
            })
            .eraseToAnyPublisher()
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let subject = captureSubject else { return }
        captureSubject = nil

        if let error {
            print("사진 처리 중 에러 발생: \(error.localizedDescription)")
            delegate?.cameraManager(self, didFailWithError: error)
            subject.send(completion: .failure(error))
            return
        }

        subject.send(photo)
        delegate?.cameraManager(self, didCapturePhoto: photo)
        subject.send(completion: .finished)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        AudioServicesDisposeSystemSoundID(1108)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        AudioServicesDisposeSystemSoundID(1108)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFailToCapturePhoto photo: AVCapturePhoto?, error: Error, from resolvedSettings: AVCaptureResolvedPhotoSettings) {
        guard let subject = captureSubject else { return }
        captureSubject = nil
        print("사진 촬영 실패: \(error.localizedDescription)")
        delegate?.cameraManager(self, didFailWithError: error)
        subject.send(completion: .failure(error))
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        guard let subject = captureSubject, let error else { return }
        captureSubject = nil
        print("사진 촬영 완료 실패: \(error.localizedDescription)")
        delegate?.cameraManager(self, didFailWithError: error)
        subject.send(completion: .failure(error))
    }
    
    //줌 범위를 확인하고 부드럽게 해주는 줌 모션을 관리하는 함수
    func zoom(_ zoom: CGFloat) {
        guard let device = self.videoDeviceInput?.device else { return }

        sessionService.configureSession(session, reason: "manager.zoom") {
            do {
                try device.lockForConfiguration()

                // 광학 줌 단계 확인 (듀얼/트리플 카메라)
                let zoomFactors = device.virtualDeviceSwitchOverVideoZoomFactors as? [NSNumber] ?? []
                print("Available zoom factors: \(zoomFactors)") // 사용 가능한 줌 단계 확인

                // 줌 범위 설정
                let minZoom = device.minAvailableVideoZoomFactor
                let maxZoom = min(device.maxAvailableVideoZoomFactor, 10.0) // 최대 10배로 제한
                var finalZoom = min(max(zoom, minZoom), maxZoom)

                // 광학 줌 단계와 가까운 경우 해당 단계로 스냅
                if !zoomFactors.isEmpty {
                    for factor in zoomFactors {
                        let zoomFactor = CGFloat(truncating: factor)
                        if abs(finalZoom - zoomFactor) < 0.3 {  // 0.3 이내면 광학 줌 단계로 스냅
                            finalZoom = zoomFactor
                            break
                        }
                    }
                }

                // 부드러운 줌 적용
                let rate: Double = finalZoom <= 2.0 ? 30.0 : 100.0  // 광학 줌 범위에서는 더 부드럽게
                device.ramp(toVideoZoomFactor: finalZoom, withRate: Float(rate))

                device.unlockForConfiguration()
            } catch {
                print("줌 설정 오류: \(error.localizedDescription)")
            }
        }
    }
}
