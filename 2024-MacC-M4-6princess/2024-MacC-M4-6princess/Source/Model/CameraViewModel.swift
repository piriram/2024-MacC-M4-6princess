//
//  CameraModel.swift
//  2024-MacC-M4-6princess
//
//  Created by 김이예은 on 10/1/24.
//

import SwiftUI
import AVFoundation
import Photos
import Combine

enum CapturePipelineState: Equatable {
    case idle
    case scheduled
    case capturing
    case processing
    case readyToNavigate
    case saving
    case completed
    case failed
    case cancelled
}

enum CapturePipelineError: Error, LocalizedError {
    case invalidPhotoData
    case invalidImage
    case cropFailed
    case viewModelDeallocated

    var errorDescription: String? {
        switch self {
        case .invalidPhotoData:
            return "사진 데이터가 유효하지 않습니다."
        case .invalidImage:
            return "이미지 변환에 실패했습니다."
        case .cropFailed:
            return "이미지 크롭에 실패했습니다."
        case .viewModelDeallocated:
            return "카메라 뷰모델이 해제되었습니다."
        }
    }
}

class CameraViewModel: NSObject, ObservableObject {

    @Published var isTakenPhoto = false
    @Published var isAllTakenPhoto = false
    @Published var isSavedPhotoData = false
    @Published var picData = Data(count: 0)
    @Published var takenImg: UIImage?

    // 캡처 플로우 상태
    @Published private(set) var captureState: CapturePipelineState = .idle
    @Published private(set) var routeToResult: Bool = false
    @Published private(set) var isResultNavigationInProgress: Bool = false
    @Published private(set) var capturedFrameImage: UIImage?
    // 기존 뷰에서 쓰던 하위호환 플래그
    @Published var frameSize = CGRect(origin: .zero, size: .zero)
    @Published var preview: AVCaptureVideoPreviewLayer!
    @Published private(set) var isUsingSampleCamera: Bool = false
    @Published private(set) var samplePreviewImage: UIImage?

    // 프레임 관련 상태
    @Published private(set) var frameRatio: CGFloat = CameraDisplayPolicyStore.current.aspect.spec.ratio

    // 타이머 관련 상태
    @Published var delayTime: TimeInterval = 0.0
    @Published var isTakePic = false
    @Published var remainingTime: TimeInterval = 0
    @Published var backgroundOpacity: Double = 0
    @Published var opacity: Double = 1
    @Published var showCountdown: Bool = true

    // 타이머 관련 상태 - iPad
    @Published var isPushedTimer: Int = 0

    // 프레임 선택 관련 상태
    @Published var isShowAlert = false //프레임 없을 때 alert
    @Published var inputImage: UIImage?

    //줌 관련
    @Published var currentZoomFactor: CGFloat = 1.0
    @Published var lastScale: CGFloat = 1.0

    //카메라 화면전환 관련
    @Published var cameraPosition: AVCaptureDevice.Position = .back

    @Published var showOrientationAlert: Bool = false

    //오류 알림
    @Published var showErrorAlert = false
    @Published var errorMessage: String = ""
    // 이미지 관련
    @Published var idolImg: UIImage
    let defaultImg: UIImage
    var ScreenSize:CGSize = UIScreen.main.bounds.size
    private var cameraProvider: CameraProviding
    let motionManager = MotionManager()
    private var cancellables: Set<AnyCancellable> = []

    init(cameraProvider: CameraProviding = CameraProviderFactory.makeDefault()) {
        self.cameraProvider = cameraProvider
        self.idolImg = UIImage(named: "Felix") ?? UIImage()
        self.defaultImg = UIImage(named: "whiteBG") ?? UIImage()
        super.init()
        setupPreviewLayer()
        syncDisplayPolicy()
        syncProviderState()
        _ = motionManager
    }

    convenience init(cameraManager: CameraManager) {
        self.init(cameraProvider: DeviceCameraProvider(cameraManager: cameraManager))
    }

    private func setupPreviewLayer() {
        preview = AVCaptureVideoPreviewLayer(session: cameraProvider.session)
        preview.videoGravity = CameraDisplayPolicyStore.current.previewMode.videoGravity
    }

    private func syncDisplayPolicy() {
        let policy = CameraDisplayPolicyStore.current
        frameRatio = policy.aspectSpec.ratio
        preview.videoGravity = policy.previewMode.videoGravity
    }

    func handleCapturedPhoto(_ frame: CameraCaptureFrame) {
        guard !routeToResult,
              captureState != .readyToNavigate,
              !isResultNavigationInProgress else { return }

        do {
            let image = try makeCapturedImage(from: frame)
            applyCapturedPhoto(image)
        } catch {
            handleCaptureError(error)
        }
    }

    private func applyCapturedPhoto(_ image: UIImage) {
        guard !routeToResult,
              !isResultNavigationInProgress,
              captureState != .readyToNavigate else {
            return
        }

        self.picData = image.jpegData(compressionQuality: 1.0) ?? Data()
        self.takenImg = image

        self.captureState = .readyToNavigate
        self.routeToResult = true
        print("사진이 성공적으로 처리되었습니다")

        self.isTakenPhoto = false
        self.isTakePic = false
    }

    private func makeCapturedImage(from frame: CameraCaptureFrame) throws -> UIImage {
        var capturedImage: UIImage

        switch frame {
        case .photo(let photo):
            guard let imageData = photo.fileDataRepresentation() else {
                print("사진 데이터가 유효하지 않음")
                throw CapturePipelineError.invalidPhotoData
            }
            guard let decoded = UIImage(data: imageData) else {
                print("이미지를 생성할 수 없습니다.")
                throw CapturePipelineError.invalidImage
            }
            capturedImage = decoded
        case .image(let providedImage):
            capturedImage = providedImage
        }

        // 전면 카메라일 경우 좌우 반전 처리
        if cameraProvider.cameraPosition == .front {
            guard let mirroredCGImage = capturedImage.cgImage else {
                print("전면 카메라 이미지 처리 실패: cgImage 없음")
                throw CapturePipelineError.invalidImage
            }
            capturedImage = UIImage(cgImage: mirroredCGImage, scale: capturedImage.scale, orientation: .leftMirrored)
        }

        // 이미지의 방향을 .up으로 수정. 이미지 프리뷰를 위함
        capturedImage = fixOrientation(capturedImage)

        guard let processedImage = applyOutputPolicy(to: capturedImage).cgImage else {
            throw CapturePipelineError.cropFailed
        }

        return UIImage(cgImage: processedImage, scale: capturedImage.scale, orientation: capturedImage.imageOrientation)
    }

    private func handleCaptureError(_ error: Error, showAlert: Bool = true) {
        DispatchQueue.main.async {
            if showAlert {
                self.errorMessage = "촬영 실패: \(error.localizedDescription)"
                self.showErrorAlert = true
            }

            self.isTakenPhoto = false
            self.isTakePic = false
            self.captureState = .failed
            self.capturedFrameImage = nil
            self.routeToResult = false
            self.isResultNavigationInProgress = false
        }
    }

    // 기기 방향에 따라 이미지 회전하는 함수 추가
    func rotateImage(_ image: UIImage, basedOn orientation: UIDeviceOrientation) -> UIImage {
        switch orientation {
        case .landscapeLeft:
            return image.rotate(radians: .pi/2)  // 오른쪽으로 90도 회전
        case .landscapeRight:
            return image.rotate(radians: -.pi/2)  // 왼쪽으로 90도 회전
        default:
            return image
        }
    }

    // 캡처 결과를 정책에 맞춰 출력 처리
    private func applyOutputPolicy(to image: UIImage) -> UIImage {
        let policy = CameraDisplayPolicyStore.current

        switch policy.outputMode {
        case .passThrough:
            return image
        case .cropCenter:
            return cropToAspectRatio(image: image, targetRatio: policy.aspectSpec.ratio)
        }
    }

    // 이미지를 비율에 맞게 중앙 크롭
    private func cropToAspectRatio(image: UIImage, targetRatio: CGFloat) -> UIImage {
        guard let cgImage = image.cgImage else {
            return image
        }

        let sourceWidth = CGFloat(cgImage.width)
        let sourceHeight = CGFloat(cgImage.height)
        guard sourceWidth > 0 && sourceHeight > 0 && targetRatio > 0 else { return image }

        let targetHeight = sourceWidth * targetRatio
        if sourceHeight >= targetHeight {
            let cropHeight = targetHeight
            let topOffset = max(0, (sourceHeight - cropHeight) / 2)
            let cropRect = CGRect(x: 0, y: topOffset, width: sourceWidth, height: min(cropHeight, sourceHeight - topOffset))
            guard let cropped = image.cgImage?.cropping(to: cropRect) else {
                return image
            }
            return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
        }

        // 세로가 짧아 크롭이 불가능한 경우는 가운데 기준 패딩 없이, 원본을 그대로 유지
        // (현재 카메라 입력 기준으로는 crop 실패 케이스가 드묾)
        return image
    }

    //셔터가 눌리면 실행되는 함수
    func takePic() {
        if isResultNavigationInProgress || routeToResult {
            return
        }

        switch captureState {
        case .scheduled:
            break
        case .idle, .completed, .failed:
            captureState = .scheduled
        case .readyToNavigate, .saving, .cancelled:
            return
        default:
            return
        }

        let delay = cameraProvider.isSessionRunning ? 0.0 : 0.5
        captureState = .capturing
        isTakenPhoto = true

        Just(())
            .delay(for: .seconds(delay), scheduler: DispatchQueue.main)
            .flatMap { [weak self] _ -> AnyPublisher<CameraCaptureFrame, Error> in
                guard let self else {
                    return Fail(error: CapturePipelineError.viewModelDeallocated)
                        .eraseToAnyPublisher()
                }
                return self.cameraProvider.takePicture()
            }
            .tryMap { [weak self] frame -> UIImage in
                guard let self else { throw CapturePipelineError.viewModelDeallocated }
                self.captureState = .processing
                return try self.makeCapturedImage(from: frame)
            }
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self else { return }
                    self.isTakenPhoto = false
                    self.isTakePic = false

                    if case .failure(let error) = completion {
                        self.handleCaptureError(error)
                    }
                },
                receiveValue: { [weak self] image in
                    guard let self else { return }
                    self.captureState = .saving
                    self.applyCapturedPhoto(image)
                }
            )
            .store(in: &cancellables)
    }

    @discardableResult
    func beginCapture(frameSnapshot: UIImage? = nil) -> Bool {
        guard !isResultNavigationInProgress,
              !routeToResult,
              captureState == .idle || captureState == .completed || captureState == .failed else {
            return false
        }

        captureState = .scheduled
        routeToResult = false
        isResultNavigationInProgress = false
        capturedFrameImage = frameSnapshot
        isTakenPhoto = true
        isTakePic = false
        showErrorAlert = false
        errorMessage = ""
        return true
    }

    func beginResultNavigation() {
        isResultNavigationInProgress = true
    }

    func finishResultNavigation() {
        routeToResult = false
        isResultNavigationInProgress = false

        if captureState == .readyToNavigate {
            captureState = .completed
        }

        capturedFrameImage = nil
        isTakePic = false
        isTakenPhoto = false
    }

    func cancelCaptureIfNeeded(showCancellationError: Bool = false) {
        guard captureState == .scheduled || captureState == .capturing || captureState == .processing else {
            return
        }

        cancellables.removeAll()

        if showCancellationError {
            handleCaptureError(NSError(domain: "CameraViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "촬영이 취소되었습니다."]))
        } else {
            captureState = .cancelled
            capturedFrameImage = nil
            isTakenPhoto = false
            isTakePic = false
            routeToResult = false
            isResultNavigationInProgress = false
            showErrorAlert = false
            errorMessage = ""
        }
    }

    func resetCaptureState() {
        if captureState == .scheduled || captureState == .capturing || captureState == .processing {
            cancellables.removeAll()
        }

        captureState = .idle
        capturedFrameImage = nil
        isTakenPhoto = false
        isTakePic = false
        routeToResult = false
        isResultNavigationInProgress = false
        showErrorAlert = false
        errorMessage = ""
    }

    func refreshRuntimeDependencies() {
        cameraProvider.stopSession()
        cameraProvider = CameraProviderFactory.makeDefault()
        syncProviderState()
        setupPreviewLayer()
        syncDisplayPolicy()
    }

    private func syncProviderState() {
        if cameraProvider.deviceType == .builtInWideAngleCamera {
            currentZoomFactor = 2.0
        } else {
            currentZoomFactor = 1.0
        }
        cameraPosition = cameraProvider.cameraPosition
        isUsingSampleCamera = cameraProvider.isSampleProvider
        samplePreviewImage = cameraProvider.samplePreviewImage
    }

    var activeDeviceType: AVCaptureDevice.DeviceType {
        cameraProvider.deviceType
    }

    var previewSession: AVCaptureSession {
        cameraProvider.session
    }

    func checkVideoAuthorization() {
        cameraProvider.checkVideoAuthorizaion()
    }

    func startCameraSession() {
        cameraProvider.startSession()
    }

    func stopCameraSession() {
        cameraProvider.stopSession()
    }

    //카메라 전후면 전환(초기 줌 팩터를 다시 맞춰줌)
    func changeCamera() {
        cameraProvider.changeCamera()
        cameraPosition = cameraProvider.cameraPosition

        // 카메라 전환 시 적절한 초기 줌 팩터 설정
        if cameraPosition == .back {
            if cameraProvider.deviceType == .builtInUltraWideCamera {
                currentZoomFactor = 2.0
            } else {
                currentZoomFactor = 1.0
            }
        } else {
            currentZoomFactor = 1.0
        }

        lastScale = 1.0
    }

    //이미지 방향 수정 함수
    func fixOrientation(_ image: UIImage) -> UIImage {
        // 이미지의 방향이 이미 .up이면 그대로 반환
        if image.imageOrientation == .up {
            return image
        }

        // 그래픽 컨텍스트 생성
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))

        // 새로운 UIImage 생성
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()

        return normalizedImage
    }

    //메인 줌 함수
    func zoom(factor: CGFloat) {
        let delta = factor / lastScale
        lastScale = factor

        // 현재 줌 상태에서 변화량을 적용
        var newZoomFactor = currentZoomFactor * delta

        // 최소/최대 줌 팩터 제한
        if let device = cameraProvider.videoDeviceInput?.device {
            let minZoom: CGFloat = 1.0
            let maxZoom: CGFloat = device.deviceType == .builtInUltraWideCamera ? 4.0 : 3.0
            newZoomFactor = min(max(newZoomFactor, minZoom), maxZoom)

            // 줌 적용
            cameraProvider.zoom(newZoomFactor)

            // currentZoomFactor 실시간 업데이트
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                currentZoomFactor = newZoomFactor
            }
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                currentZoomFactor = min(max(newZoomFactor, 1.0), 4.0)
            }
        }
    }

    //해당 factor로 줌을 해주는 함수
    func setZoom(factor: CGFloat) {
        guard let device = cameraProvider.videoDeviceInput?.device else {
            currentZoomFactor = factor
            return
        }

        do {
            try device.lockForConfiguration()
            let actualZoomFactor = if device.position == .back {
                if cameraProvider.deviceType == .builtInUltraWideCamera {
                    factor
                } else {
                    factor * 2
                }
            } else {
                factor
            }

            device.ramp(toVideoZoomFactor: actualZoomFactor, withRate: 100.0)
            device.videoZoomFactor = actualZoomFactor
            device.unlockForConfiguration()
            currentZoomFactor = factor // 실제 줌 팩터 저장
        } catch {
            print("줌 설정 오류: \(error.localizedDescription)")
        }
    }

    //줌 스케일 초기화
    func zoomInitialize() {
        lastScale = 1.0  // 제스처를 위한 scale만 초기화
        print("lastScale 초기화됨")
    }

    //기기에 따른 줌 범위 설정
    func getZoomRange(for device: AVCaptureDevice) -> ClosedRange<CGFloat> {
        if device.position == .back {
            switch device.deviceType {
            case .builtInUltraWideCamera:
                return 2.0...4.0
            case .builtInWideAngleCamera:
                return 1.0...3.0
            default:
                return 1.0...device.maxAvailableVideoZoomFactor
            }
        } else {
            // 전면 카메라는 1.0...3.0 범위 사용
            return 1.0...3.0
        }
    }


}
