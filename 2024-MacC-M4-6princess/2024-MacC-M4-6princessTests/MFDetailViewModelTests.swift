import XCTest
@testable import _024_MacC_M4_6princess

final class MFDetailViewModelTests: XCTestCase {
    func testLoadSubjectsForModifySetsCoreDataFetchErrorOnFailure() {
        let viewModel = MFDetailViewModel(storeImageService: FailingStoreImageService())
        let imageModel = ImageListModel()

        let success = viewModel.loadSubjectsForModify(frameId: UUID(), imageModel: imageModel)

        XCTAssertFalse(success)
        if case .coreDataFetchFailed? = viewModel.appError {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected coreDataFetchFailed")
        }
    }

    func testLoadSubjectsForModifyReturnsFalseWhenFrameIdMissing() {
        let viewModel = MFDetailViewModel(storeImageService: FailingStoreImageService())
        let imageModel = ImageListModel()

        let success = viewModel.loadSubjectsForModify(frameId: nil, imageModel: imageModel)

        XCTAssertFalse(success)
    }
}

private struct FailingStoreImageService: StoreImagePersisting {
    func fetchRecords(sort: StoreImageSortOption) throws -> [StoreImageRecord] { [] }
    func fetchImageData(for id: UUID) throws -> Data? { nil }
    func fetchSubjectRecords(for id: UUID) throws -> [StoredSubjectRecord] {
        throw NSError(domain: "test", code: 1)
    }
    func deleteImage(id: UUID) throws {}
    func deleteImages(ids: Set<UUID>) throws {}
    func deleteImagesAndReturnCount(ids: Set<UUID>) throws -> Int { 0 }
}
