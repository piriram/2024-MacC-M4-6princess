import Foundation
import CoreImage
import Vision

enum SubjectMaskingError: Error {
    case noResult
}

protocol SubjectMaskingServicing {
    func makeMask(from inputImage: CIImage) throws -> CIImage
}

struct VisionSubjectMaskingService: SubjectMaskingServicing {
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

struct StubSubjectMaskingService: SubjectMaskingServicing {
    func makeMask(from inputImage: CIImage) throws -> CIImage {
        CIImage(color: CIColor(red: 1, green: 1, blue: 1, alpha: 1)).cropped(to: inputImage.extent)
    }
}

enum SubjectMaskingServiceFactory {
    static func makeDefault() -> SubjectMaskingServicing {
        let env = ProcessInfo.processInfo.environment
        if env["USE_STUB_MASK"] == "1" {
            return StubSubjectMaskingService()
        }

        #if targetEnvironment(simulator)
        return StubSubjectMaskingService()
        #else
        return VisionSubjectMaskingService()
        #endif
    }
}
