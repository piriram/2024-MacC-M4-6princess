import Foundation
import UIKit
import AVFoundation
import Combine

enum CameraCaptureFrame {
    case photo(AVCapturePhoto)
    case image(UIImage)
}

protocol CameraProviding: AnyObject {
    var session: AVCaptureSession { get }
    var videoDeviceInput: AVCaptureDeviceInput? { get }
    var deviceType: AVCaptureDevice.DeviceType { get }
    var cameraPosition: AVCaptureDevice.Position { get }
    var isSessionRunning: Bool { get }
    var isSampleProvider: Bool { get }
    var samplePreviewImage: UIImage? { get }

    func checkVideoAuthorizaion()
    func startSession()
    func stopSession()
    func changeCamera()
    func takePicture() -> AnyPublisher<CameraCaptureFrame, Error>
    func zoom(_ zoom: CGFloat)
}

final class DeviceCameraProvider: CameraProviding {
    let cameraManager: CameraManager

    init(cameraManager: CameraManager = CameraManager()) {
        self.cameraManager = cameraManager
    }

    var session: AVCaptureSession { cameraManager.session }
    var videoDeviceInput: AVCaptureDeviceInput? { cameraManager.videoDeviceInput }
    var deviceType: AVCaptureDevice.DeviceType { cameraManager.deviceType }
    var cameraPosition: AVCaptureDevice.Position { cameraManager.videoDeviceInput?.device.position ?? .back }
    var isSessionRunning: Bool { cameraManager.session.isRunning }
    var isSampleProvider: Bool { false }
    var samplePreviewImage: UIImage? { nil }

    func checkVideoAuthorizaion() {
        cameraManager.checkVideoAuthorizaion()
    }

    func startSession() {
        cameraManager.startSession()
    }

    func stopSession() {
        cameraManager.stopSession()
    }

    func changeCamera() {
        cameraManager.changeCamera()
    }

    func takePicture() -> AnyPublisher<CameraCaptureFrame, Error> {
        cameraManager.takePicture()
            .map { CameraCaptureFrame.photo($0) }
            .eraseToAnyPublisher()
    }

    func zoom(_ zoom: CGFloat) {
        cameraManager.zoom(zoom)
    }
}

final class SampleCameraProvider: CameraProviding {
    private let sessionInstance = AVCaptureSession()
    private let sampleImage: UIImage
    private(set) var position: AVCaptureDevice.Position = .back
    private(set) var running = false

    init(sampleImage: UIImage = SampleCameraProvider.makeDefaultSampleImage()) {
        self.sampleImage = sampleImage
    }

    var session: AVCaptureSession { sessionInstance }
    var videoDeviceInput: AVCaptureDeviceInput? { nil }
    var deviceType: AVCaptureDevice.DeviceType { .builtInWideAngleCamera }
    var cameraPosition: AVCaptureDevice.Position { position }
    var isSessionRunning: Bool { running }
    var isSampleProvider: Bool { true }
    var samplePreviewImage: UIImage? { sampleImage }

    func checkVideoAuthorizaion() {
        running = true
    }

    func startSession() {
        running = true
    }

    func stopSession() {
        running = false
    }

    func changeCamera() {
        position = (position == .front) ? .back : .front
    }

    func takePicture() -> AnyPublisher<CameraCaptureFrame, Error> {
        Just(CameraCaptureFrame.image(sampleImage))
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func zoom(_ zoom: CGFloat) {
        _ = zoom
    }

    private static func makeDefaultSampleImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1080, height: 1440))
        return renderer.image { context in
            let colors = [
                UIColor(red: 0.96, green: 0.76, blue: 0.36, alpha: 1.0).cgColor,
                UIColor(red: 0.93, green: 0.43, blue: 0.35, alpha: 1.0).cgColor
            ] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0.0, 1.0])

            let rect = CGRect(origin: .zero, size: CGSize(width: 1080, height: 1440))
            if let gradient {
                context.cgContext.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: rect.maxX, y: rect.maxY),
                    options: []
                )
            }

            let text = "Simulator Sample"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 72, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let textSize = text.size(withAttributes: attributes)
            let textOrigin = CGPoint(
                x: (rect.width - textSize.width) / 2,
                y: (rect.height - textSize.height) / 2
            )
            text.draw(at: textOrigin, withAttributes: attributes)
        }
    }
}

enum CameraProviderFactory {
    private static let stateQueue = DispatchQueue(label: "com.024-MacC-M4-6princess.CameraProviderFactory.state")
    private static let sharedDeviceManager = CameraManager()
    private static let sharedDeviceProvider = DeviceCameraProvider(cameraManager: sharedDeviceManager)
    private static let sharedSampleProvider = SampleCameraProvider()
    private static var didPrewarmDeviceRuntime = false

    static func makeDefault() -> CameraProviding {
        make(source: RuntimeTestingOptions.cameraSource())
    }

    static func make(source: CameraSourceOption) -> CameraProviding {
        let resolved = RuntimeSelectionResolver.resolvedCameraSource(
            preferred: source,
            isSimulator: RuntimeTestingOptions.isSimulator,
            isRealCameraAvailable: RuntimeTestingOptions.isRealCameraAvailable
        )

        switch resolved {
        case .device:
            prewarmDeviceRuntimeIfNeeded()
            print("[CameraStartup] provider decision=device reuse=shared")
            return sharedDeviceProvider
        case .sample:
            print("[CameraStartup] provider decision=sample reuse=shared")
            return sharedSampleProvider
        }
    }

    private static func prewarmDeviceRuntimeIfNeeded() {
        let shouldPrewarm = stateQueue.sync { () -> Bool in
            if didPrewarmDeviceRuntime {
                return false
            }
            didPrewarmDeviceRuntime = true
            return true
        }

        if shouldPrewarm {
            print("[CameraStartup] prewarm decision=trigger")
            sharedDeviceManager.prewarmSessionIfPossible()
        } else {
            print("[CameraStartup] prewarm decision=already-done")
        }
    }
}
