import Foundation
import UIKit

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
}
