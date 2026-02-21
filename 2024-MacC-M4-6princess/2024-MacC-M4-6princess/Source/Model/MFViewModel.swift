import SwiftUI
import CoreData

class MFViewModel: ObservableObject {
    @Published var imageDataArray: [(id: UUID, data: Data, isLoaded: Bool)] = []
    @Published var isShowPhotosPicker: Bool = false
    @Published var isEditing: Bool = false
    @Published var selectedImageIds: Set<UUID> = []
    @Published var isDeleteAlert: Bool = false
    @Published var isDeleteAlertDetail: Bool = false
    @Published var isShowMFDetailView: Bool = false

    private var imageCache: [UUID: Data] = [:]
    private let storeImageService: StoreImagePersisting

    init(context: NSManagedObjectContext, storeImageService: StoreImagePersisting? = nil) {
        self.storeImageService = storeImageService ?? StoreImagePersistenceService(context: context)
    }

    /// 코어데이터에서 이미지 id를 가져옴
    func loadImages() {
        do {
            let records = try storeImageService.fetchRecords(sort: .createdDateAscending)
            imageDataArray = records.map { (id: $0.id, data: Data(), isLoaded: false) }
        } catch {
            print("이미지 로드 실패: \(error)")
        }
    }

    /// 특정 이미지가 필요할 때 로드(해당 Id가 없을 때만 로드)
    func loadImageIfNeeded(for id: UUID) -> Data? {
        if let cached = imageCache[id] {
            return cached
        }

        if let imageData = loadImageData(for: id) {
            imageCache[id] = imageData
            return imageData
        }
        return nil
    }

    /// 특정 이미지 데이터를 가져옴
    func loadImageData(for id: UUID) -> Data? {
        do {
            guard let imageData = try storeImageService.fetchImageData(for: id),
                  let image = UIImage(data: imageData),
                  let downsampled = downsampleImage(
                    image,
                    to: CGSize(
                        width: UIScreen.main.bounds.width / 3,
                        height: (UIScreen.main.bounds.width / 3) * (4 / 3)
                    )
                  )?.pngData()
            else {
                return nil
            }
            return downsampled
        } catch {
            print("이미지 로딩 실패: \(error)")
            return nil
        }
    }

    /// 원본 이미지 데이터를 가져오는 함수
    func loadOriginalImageData(for id: UUID) -> Data? {
        do {
            return try storeImageService.fetchImageData(for: id)
        } catch {
            print("원본 이미지 로딩 실패: \(error)")
            return nil
        }
    }

    /// 선택된 이미지들을 코어데이터에서 삭제
    func deleteSelectedImages() {
        do {
            try storeImageService.deleteImages(ids: selectedImageIds)
            loadImages()
            selectedImageIds.removeAll()
            isEditing = false
            imageCache.removeAll()
        } catch {
            print("이미지 삭제 실패: \(error)")
        }
    }

    /// 원본 이미지를 다운샘플링(메모리 줄이기)
    func downsampleImage(_ image: UIImage, to pointSize: CGSize) -> UIImage? {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let data = image.pngData(),
              let imageSource = CGImageSourceCreateWithData(data as CFData, imageSourceOptions) else {
            return nil
        }

        let maxDimensionInPixels = max(pointSize.width, pointSize.height) * UIScreen.main.scale
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels
        ] as CFDictionary

        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else {
            return nil
        }

        return UIImage(cgImage: downsampledImage)
    }

    /// 선택된 이미지의 인덱스를 반환
    func indexOfSelectedImage() -> Int? {
        guard let selectedId = selectedImageIds.first else { return nil }
        return imageDataArray.firstIndex(where: { $0.id == selectedId })?.advanced(by: 1)
    }

    /// Core Data에 저장된 총 이미지 개수를 반환
    func totalImageCount() -> Int {
        return imageDataArray.count
    }
}
