import Foundation

enum AppError: Error {
    case inputImageMissing
    case maskCreationFailed
    case imageRenderingFailed
    case coreDataFetchFailed
    case coreDataSaveFailed
    case photoLibraryPermissionDenied
    case albumCreationFailed
    case albumNotFound
    case photoSaveFailed
    case uiNotReady

    var userMessage: String {
        switch self {
        case .inputImageMissing:
            return "입력 이미지를 불러오지 못했습니다."
        case .maskCreationFailed:
            return "누끼 마스크 생성에 실패했습니다."
        case .imageRenderingFailed:
            return "이미지 렌더링에 실패했습니다."
        case .coreDataFetchFailed:
            return "데이터를 불러오는 중 오류가 발생했습니다."
        case .coreDataSaveFailed:
            return "데이터를 저장하는 중 오류가 발생했습니다."
        case .photoLibraryPermissionDenied:
            return "사진 라이브러리 권한이 필요합니다."
        case .albumCreationFailed:
            return "앨범 생성에 실패했습니다."
        case .albumNotFound:
            return "앨범을 찾을 수 없습니다."
        case .photoSaveFailed:
            return "사진 저장에 실패했습니다."
        case .uiNotReady:
            return "화면 준비가 완료되지 않았습니다."
        }
    }
}
