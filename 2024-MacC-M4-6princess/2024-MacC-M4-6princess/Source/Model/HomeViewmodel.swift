import SwiftUI
import CoreData

class HomeViewModel: ObservableObject {
    @Published var imageDataArray: [(id: UUID, data: Data, isLoaded: Bool)] = []
    private var imageCache: [UUID: Data] = [:]
    private let storeImageService: StoreImagePersisting

    init(context: NSManagedObjectContext, storeImageService: StoreImagePersisting? = nil) {
        self.storeImageService = storeImageService ?? StoreImagePersistenceService(context: context)
    }

    /// Core Data에서 이미지 ID를 가져옴
    func loadImages() {
        do {
            let records = try storeImageService.fetchRecords(sort: .createdDateAscending)
            imageDataArray = records.map { (id: $0.id, data: Data(), isLoaded: false) }
        } catch {
            print("이미지 로드 실패: \(error)")
        }
    }

    /// 특정 이미지가 필요할 때 로드 (해당 ID가 없을 때만 로드)
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

    /// 특정 이미지 데이터를 Core Data에서 가져옴
    func loadImageData(for id: UUID) -> Data? {
        do {
            guard let imageData = try storeImageService.fetchImageData(for: id),
                  let image = SafeImageDecoder.decodeImage(from: imageData),
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

    /// 이미지를 다운샘플링하여 메모리 사용량 줄이기
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
}
