import Foundation
import UIKit
import ImageIO

enum CameraSourceOption: String, CaseIterable, Identifiable {
    case device
    case sample

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .device:
            return "Device"
        case .sample:
            return "Sample"
        }
    }
}

enum CutoutEngineOption: String, CaseIterable, Identifiable {
    case real
    case mock

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .real:
            return "Real"
        case .mock:
            return "Mock"
        }
    }
}

enum PreviewTopPlacementOption: String, CaseIterable, Identifiable {
    case respectTopBar
    case overlapTopBar

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .respectTopBar:
            return "Respect Top Bar"
        case .overlapTopBar:
            return "Overlap Top Bar"
        }
    }
}

enum ShutterVerticalPlacementOption: String, CaseIterable, Identifiable {
    case topOverflow
    case centerY

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .topOverflow:
            return "Top Overflow"
        case .centerY:
            return "Center Y"
        }
    }
}

enum RuntimeSelectionResolver {
    static func defaultCameraSource(isSimulator: Bool) -> CameraSourceOption {
        isSimulator ? .sample : .device
    }

    static func defaultCutoutEngine(isSimulator: Bool) -> CutoutEngineOption {
        isSimulator ? .mock : .real
    }

    static func resolvedCameraSource(
        preferred: CameraSourceOption,
        isSimulator: Bool,
        isRealCameraAvailable: Bool
    ) -> CameraSourceOption {
        guard preferred == .device else { return .sample }
        return (isSimulator || !isRealCameraAvailable) ? .sample : .device
    }
}

enum RuntimeTestingOptions {
    private static let cameraSourceKey = "debug.camera.source"
    private static let cutoutEngineKey = "debug.cutout.engine"
    private static let previewTopPlacementKey = "debug.camera.preview.topPlacement"
    private static let shutterVerticalPlacementKey = "debug.camera.shutter.verticalPlacement"
    private static let hitTestLoggingEnabledKey = "debug.camera.hitTest.logging.enabled"

    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }

    static var isRealCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    static func cameraSource(userDefaults: UserDefaults = .standard) -> CameraSourceOption {
        #if DEBUG
        if let raw = userDefaults.string(forKey: cameraSourceKey),
           let stored = CameraSourceOption(rawValue: raw) {
            return RuntimeSelectionResolver.resolvedCameraSource(
                preferred: stored,
                isSimulator: isSimulator,
                isRealCameraAvailable: isRealCameraAvailable
            )
        }
        #endif

        return RuntimeSelectionResolver.resolvedCameraSource(
            preferred: RuntimeSelectionResolver.defaultCameraSource(isSimulator: isSimulator),
            isSimulator: isSimulator,
            isRealCameraAvailable: isRealCameraAvailable
        )
    }

    static func setCameraSource(_ value: CameraSourceOption, userDefaults: UserDefaults = .standard) {
        userDefaults.set(value.rawValue, forKey: cameraSourceKey)
    }

    static func cutoutEngine(userDefaults: UserDefaults = .standard) -> CutoutEngineOption {
        #if DEBUG
        if let raw = userDefaults.string(forKey: cutoutEngineKey),
           let stored = CutoutEngineOption(rawValue: raw) {
            return stored
        }
        #endif

        return RuntimeSelectionResolver.defaultCutoutEngine(isSimulator: isSimulator)
    }

    static func setCutoutEngine(_ value: CutoutEngineOption, userDefaults: UserDefaults = .standard) {
        userDefaults.set(value.rawValue, forKey: cutoutEngineKey)
    }

    static func previewTopPlacement(userDefaults: UserDefaults = .standard) -> PreviewTopPlacementOption {
        #if DEBUG
        if let raw = userDefaults.string(forKey: previewTopPlacementKey),
           let stored = PreviewTopPlacementOption(rawValue: raw) {
            return stored
        }
        #endif

        return .respectTopBar
    }

    static func setPreviewTopPlacement(_ value: PreviewTopPlacementOption, userDefaults: UserDefaults = .standard) {
        userDefaults.set(value.rawValue, forKey: previewTopPlacementKey)
    }

    static func shutterVerticalPlacement(userDefaults: UserDefaults = .standard) -> ShutterVerticalPlacementOption {
        #if DEBUG
        if let raw = userDefaults.string(forKey: shutterVerticalPlacementKey),
           let stored = ShutterVerticalPlacementOption(rawValue: raw) {
            return stored
        }
        #endif

        return .centerY
    }

    static func setShutterVerticalPlacement(_ value: ShutterVerticalPlacementOption, userDefaults: UserDefaults = .standard) {
        userDefaults.set(value.rawValue, forKey: shutterVerticalPlacementKey)
    }

    static func isHitTestLoggingEnabled(userDefaults: UserDefaults = .standard) -> Bool {
        #if DEBUG
        if userDefaults.object(forKey: hitTestLoggingEnabledKey) != nil {
            return userDefaults.bool(forKey: hitTestLoggingEnabledKey)
        }
        #endif

        return false
    }

    static func setHitTestLoggingEnabled(_ isEnabled: Bool, userDefaults: UserDefaults = .standard) {
        userDefaults.set(isEnabled, forKey: hitTestLoggingEnabledKey)
    }
}

enum SafeImageDecoder {
    static func decodeImage(from data: Data) -> UIImage? {
        let sourceOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]

        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions as CFDictionary) else {
            return UIImage(data: data)
        }

        let decodeOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: true,
            kCGImageSourceShouldCacheImmediately: true
        ]

        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, decodeOptions as CFDictionary) else {
            return UIImage(data: data)
        }

        return UIImage(cgImage: cgImage)
    }
}
