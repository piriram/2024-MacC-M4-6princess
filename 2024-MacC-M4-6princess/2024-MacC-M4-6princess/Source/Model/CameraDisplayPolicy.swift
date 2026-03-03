import AVFoundation
import UIKit

// MARK: - Camera aspect and rendering policy for preview/output pipeline.

struct CameraAspectSpec {
    let width: CGFloat
    let height: CGFloat

    var ratio: CGFloat { height / width }
    var aspectString: String { "\(Int(width)):\(Int(height))" }
}

enum CameraAspectPreset: String, CaseIterable {
    case ratio3x4 = "3:4"
    case ratio9x16 = "9:16"
    case ratio1x1 = "1:1"

    var spec: CameraAspectSpec {
        switch self {
        case .ratio3x4:
            return .init(width: 3, height: 4)
        case .ratio9x16:
            return .init(width: 9, height: 16)
        case .ratio1x1:
            return .init(width: 1, height: 1)
        }
    }
}

enum CameraPreviewMode {
    case fit // .resizeAspect (비율 유지, 여백 허용)
    case fill // .resizeAspectFill (비율 유지, 잘림 허용)

    var videoGravity: AVLayerVideoGravity {
        switch self {
        case .fit: return .resizeAspect
        case .fill: return .resizeAspectFill
        }
    }
}

enum CameraOutputMode {
    case cropCenter // 중앙 크롭으로 target 비율 맞춤
    case passThrough // 원본 그대로
}

struct CameraDisplayPolicy {
    let aspect: CameraAspectPreset
    let previewMode: CameraPreviewMode
    let outputMode: CameraOutputMode
    let strictNoDistortion: Bool

    static let `default`: CameraDisplayPolicy = .init(
        aspect: .ratio3x4,
        previewMode: .fit,
        outputMode: .cropCenter,
        strictNoDistortion: true
    )

    var aspectSpec: CameraAspectSpec { aspect.spec }
    var aspectMultiplier: CGFloat { aspectSpec.ratio }
}

struct CameraDisplayPolicyStore {
    static var current: CameraDisplayPolicy = .default

    #if DEBUG
    static func setPolicyForDebug(_ policy: CameraDisplayPolicy) {
        current = policy
    }
    #endif
}
