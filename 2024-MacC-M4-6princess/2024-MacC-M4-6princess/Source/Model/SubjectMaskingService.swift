import Foundation
import CoreImage
import Vision

enum SubjectMaskingError: Error {
    case noResult
}

protocol CutoutEngine {
    func makeMask(from inputImage: CIImage) throws -> CIImage
}

typealias SubjectMaskingServicing = CutoutEngine

struct RealCutoutEngine: CutoutEngine {
    func makeMask(from inputImage: CIImage) throws -> CIImage {
        let handler = VNImageRequestHandler(ciImage: inputImage)
        let request = VNGenerateForegroundInstanceMaskRequest()

        try handler.perform([request])

        guard let result = request.results?.first else {
            throw SubjectMaskingError.noResult
        }

        let mask = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
        return CIImage(cvPixelBuffer: mask)
    }
}

struct MockCutoutEngine: CutoutEngine {
    func makeMask(from inputImage: CIImage) throws -> CIImage {
        CIImage(color: CIColor(red: 1, green: 1, blue: 1, alpha: 1)).cropped(to: inputImage.extent)
    }
}

// Backward-compatible aliases for existing tests/references.
typealias VisionSubjectMaskingService = RealCutoutEngine
typealias StubSubjectMaskingService = MockCutoutEngine

enum CutoutEngineFactory {
    static func makeDefault() -> CutoutEngine {
        let env = ProcessInfo.processInfo.environment
        if env["USE_STUB_MASK"] == "1" {
            return MockCutoutEngine()
        }

        switch RuntimeTestingOptions.cutoutEngine() {
        case .real:
            return RealCutoutEngine()
        case .mock:
            return MockCutoutEngine()
        }
    }
}

enum SubjectMaskingServiceFactory {
    static func makeDefault() -> SubjectMaskingServicing {
        CutoutEngineFactory.makeDefault()
    }
}
