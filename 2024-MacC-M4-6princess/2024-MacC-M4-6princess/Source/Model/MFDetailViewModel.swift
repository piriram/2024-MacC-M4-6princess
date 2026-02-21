import SwiftUI
import CoreData

class MFDetailViewModel: ObservableObject {
    @Published var selectedImageId: UUID?
    @Published var isDeleteAlertDetail = false
    @Published var imageDataArray: [(id: UUID, data: Data)] = []

    private var storeImageService: StoreImagePersisting?

    init() { }

    func configure(context: NSManagedObjectContext, selectedId: UUID?) {
        self.storeImageService = StoreImagePersistenceService(context: context)
        self.selectedImageId = selectedId
        loadImages()
    }

    /// Core Data에서 이미지 데이터를 로드하여 imageDataArray를 채움
    func loadImages() {
        guard let service = storeImageService else { return }

        do {
            let records = try service.fetchRecords(sort: .orderAscending)
            imageDataArray = records.compactMap { record in
                guard let imageData = record.imageData else { return nil }
                return (id: record.id, data: imageData)
            }
        } catch {
            print("이미지 로드 실패: \(error)")
        }
    }

    func loadOriginalImageData() -> Data? {
        guard let service = storeImageService,
              let id = selectedImageId else { return nil }

        do {
            return try service.fetchImageData(for: id)
        } catch {
            print("이미지 로딩 실패: \(error)")
            return nil
        }
    }

    func deleteSelectedImage(completion: @escaping () -> Void) {
        guard let service = storeImageService,
              let id = selectedImageId else { return }

        do {
            try service.deleteImage(id: id)
            loadImages()
            completion()
        } catch {
            print("삭제 실패: \(error)")
        }
    }

    /// 선택된 이미지의 인덱스를 반환
    func indexOfSelectedImage() -> Int? {
        guard let selectedId = selectedImageId else { return nil }
        let totalCount = imageDataArray.count
        return imageDataArray.firstIndex(where: { $0.id == selectedId }).map { totalCount - $0 }
    }

    /// 전체 이미지 개수를 반환
    func totalImageCount() -> Int {
        return imageDataArray.count
    }
}
