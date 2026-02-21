//
//  CameraModel.swift
//  2024-MacC-M4-6princess
//
//  Created by 김이예은 on 10/26/24.
//

import SwiftUI
import AVFoundation
import Photos

protocol CameraManagerDelegate: AnyObject {
    func cameraManager(_ manager: CameraManager, didCapturePhoto photo: AVCapturePhoto)
    func cameraManager(_ manager: CameraManager, didFailWithError error: Error)
}

class CameraManager: NSObject, AVCapturePhotoCaptureDelegate {
    weak var delegate: CameraManagerDelegate?
    @Published var session: AVCaptureSession
    @Published var preset: AVCaptureSession.Preset
    @Published var videoDeviceInput: AVCaptureDeviceInput?
    @Published var output: AVCapturePhotoOutput
    @Published var startFactor: CGFloat = 1.0
    @Published var deviceType: AVCaptureDevice.DeviceType
    private let sessionService: CameraSessionServicing
    private var isConfiguring = false

    init(session: AVCaptureSession = AVCaptureSession(),
         videoDeviceInput: AVCaptureDeviceInput? = nil,
         output: AVCapturePhotoOutput = AVCapturePhotoOutput(),
         sessionService: CameraSessionServicing = CameraSessionService()) {
        self.session = session
        self.preset = .photo
        self.videoDeviceInput = videoDeviceInput
        self.output = output
        self.deviceType = .builtInWideAngleCamera
        self.sessionService = sessionService
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

    //카메라 접근권한 체크 함수
    func checkVideoAuthorizaion() {
        sessionService.requestVideoAuthorization { [weak self] state in
            guard let self else { return }
            switch state {
            case .authorized:
                DispatchQueue.main.async {
                    self.setUp()
                }
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
    func setUp() {
        guard !isConfiguring else { return }
        isConfiguring = true

        session.beginConfiguration()
        defer {
            session.commitConfiguration()
            isConfiguring = false
        }

        if session.canSetSessionPreset(preset) {
            session.sessionPreset = preset
        }

        session.inputs.forEach { input in
            session.removeInput(input)
        }
        session.outputs.forEach { output in
            session.removeOutput(output)
        }

        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInTripleCamera,
                .builtInDualWideCamera,
                .builtInDualCamera,
                .builtInUltraWideCamera,
                .builtInWideAngleCamera
            ],
            mediaType: .video,
            position: .unspecified
        )

        guard let device = getBestCamera(from: discoverySession.devices) else {
            print("사용 가능한 카메라를 찾을 수 없습니다")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                print("카메라 입력을 추가할 수 없습니다")
                return
            }
            session.addInput(input)
            self.videoDeviceInput = input
            self.deviceType = device.deviceType

            try configureDeviceForCapture(device)

            guard session.canAddOutput(self.output) else {
                print("카메라 출력을 추가할 수 없습니다")
                return
            }
            session.addOutput(self.output)
            self.output.isHighResolutionCaptureEnabled = true

            if let videoConnection = self.output.connection(with: .video),
               videoConnection.isVideoStabilizationSupported {
                videoConnection.preferredVideoStabilizationMode = .standard
            }

            startSession()
        } catch {
            print("카메라 입력 설정 오류: \(error)")
        }
    }

    private func configureDeviceForCapture(_ device: AVCaptureDevice) throws {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }

        let defaultZoom: CGFloat = device.deviceType == .builtInUltraWideCamera ? 2.0 : 1.0
        if defaultZoom <= maxZoomFactor(for: device) {
            device.videoZoomFactor = max(device.minAvailableVideoZoomFactor, defaultZoom)
        }
        startFactor = device.videoZoomFactor
    }

    //기기의 카메라 렌즈 사양에 따라 카메라(비디오렌즈)를 선택
    func getBestCamera(from devices: [AVCaptureDevice]) -> AVCaptureDevice? {
        // 우선순위에 따라 카메라 선택
        if let tripleCamera = devices.first(where: { $0.deviceType == .builtInTripleCamera }) {
            return tripleCamera
        }
        if let dualWideCamera = devices.first(where: { $0.deviceType == .builtInDualWideCamera }) {
            return dualWideCamera
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

        return devices.first
    }

    //카메라 전후면 전환
    func changeCamera() {
        guard let currentInput = self.session.inputs.first as? AVCaptureDeviceInput else { return }

        session.beginConfiguration()
        session.removeInput(currentInput)

        let newPosition: AVCaptureDevice.Position = currentInput.device.position == .front ? .back : .front

        // 후면 카메라로 전환할 때는 항상 UltraWide 카메라를 먼저 시도
        let targetDeviceType: AVCaptureDevice.DeviceType = (newPosition == .back) ? .builtInUltraWideCamera : .builtInWideAngleCamera

        guard let newDevice = AVCaptureDevice.default(targetDeviceType, for: .video, position: newPosition),
              let newInput = try? AVCaptureDeviceInput(device: newDevice) else {
            // UltraWide 카메라가 없는 경우 WideAngle로 폴백
            guard let fallbackDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
                  let fallbackInput = try? AVCaptureDeviceInput(device: fallbackDevice) else { return }

            if session.canAddInput(fallbackInput) {
                session.addInput(fallbackInput)
                self.videoDeviceInput = fallbackInput
                self.deviceType = .builtInWideAngleCamera

                do {
                    try configureDeviceForCapture(fallbackDevice)
                } catch {
                    print("줌 설정 오류: \(error)")
                }
            }
            session.commitConfiguration()
            return
        }

        if session.canAddInput(newInput) {
            session.addInput(newInput)
            self.videoDeviceInput = newInput
            self.deviceType = targetDeviceType

            do {
                try configureDeviceForCapture(newDevice)
            } catch {
                print("카메라 전환 시 줌 설정 오류: \(error)")
            }
        }

        session.commitConfiguration()
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
    func takePicture(delegate: AVCapturePhotoCaptureDelegate) {
        guard session.isRunning else {
            print("세션이 실행중이지 않습니다")
            return
        }

        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        settings.isHighResolutionPhotoEnabled = output.isHighResolutionCaptureEnabled

        if #available(iOS 15.0, *) {
            settings.photoQualityPrioritization = .quality
        }

        // 메인 스레드에서 실행
        DispatchQueue.main.async {
            self.output.capturePhoto(with: settings, delegate: delegate)
        }
    }

    func maxZoomFactor(for device: AVCaptureDevice) -> CGFloat {
        if device.position == .back {
            switch device.deviceType {
            case .builtInUltraWideCamera:
                return min(device.maxAvailableVideoZoomFactor, 4.0)
            case .builtInWideAngleCamera:
                return min(device.maxAvailableVideoZoomFactor, 3.0)
            default:
                return min(device.maxAvailableVideoZoomFactor, 10.0)
            }
        } else {
            return min(device.maxAvailableVideoZoomFactor, 3.0)
        }
    }

    //줌 범위를 확인하고 부드럽게 해주는 줌 모션을 관리하는 함수
    func zoom(_ zoom: CGFloat) {
        guard let device = self.videoDeviceInput?.device else { return }

        do {
            try device.lockForConfiguration()

            // 광학 줌 단계 확인 (듀얼/트리플 카메라)
            let zoomFactors = device.virtualDeviceSwitchOverVideoZoomFactors
            print("Available zoom factors: \(zoomFactors)") // 사용 가능한 줌 단계 확인

            // 줌 범위 설정
            let minZoom = device.minAvailableVideoZoomFactor
            let maxZoom = max(minZoom, maxZoomFactor(for: device))
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
