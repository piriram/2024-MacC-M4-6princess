import SwiftUI
import Photos

class PhotosPickerViewModel: ObservableObject {
    private enum Constants {
        static let pageSize = 60
        static let thumbnailTargetSize = CGSize(width: 180, height: 180)
        static let prefetchMargin = 30
    }

    @Published var models: [PickedImageModel] = []
    @Published var selectedIndex: Int = -1
    @Published var outputImage: UIImage?
    @Published var messageOpacity: Double = 1
    @Published var fetchedAlbum: Int = Constants.pageSize
    @Published var firstAppear: Bool = true
    @Published var canLoadMorePages: Bool = false

    private let imageManager = PHCachingImageManager()
    private var isLoadingPage: Bool = false
    private var prefetchedAssetRange = 0..<0
    
    var album: PHFetchResult<PHAsset> = PHFetchResult<PHAsset>()
    var viewSize: CGSize = .zero
    var offset: CGFloat = 0
    var originOffset: CGFloat = 0
    var isCheckedOriginOffset: Bool = false

    func setViewSize(_ size: CGSize) {
        self.viewSize = size
    }

    func setOriginOffset(_ offset: CGFloat) {
        guard !isCheckedOriginOffset else { return }
        self.originOffset = offset
        isCheckedOriginOffset = true
    }

    func setOffset(_ offset: CGFloat) {
        self.offset = offset
    }

    func changeOpacity() {
        for _ in 0..<10 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.messageOpacity = max(0, self.messageOpacity - 0.1)
            }
        }
    }

    func fetchInitialAlbum() -> Range<Int> {
        guard !isLoadingPage else { return 0..<0 }

        fetchedAlbum = Constants.pageSize
        prefetchedAssetRange = 0..<0
        imageManager.stopCachingImagesForAllAssets()
        return fetchAlbumPage(limit: fetchedAlbum)
    }

    func fetchNextPage() -> Range<Int> {
        guard !isLoadingPage else { return 0..<0 }
        let previousCount = album.count

        let nextLimit = previousCount + Constants.pageSize
        return fetchAlbumPage(limit: nextLimit, previousCount: previousCount)
    }

    func prefetchAround(index: Int) {
        guard album.count > 0 else { return }

        let clampedIndex = min(max(0, index), album.count - 1)
        let start = max(0, clampedIndex - Constants.prefetchMargin)
        let end = min(album.count, clampedIndex + Constants.prefetchMargin + 1)
        let range = start..<end

        guard range != prefetchedAssetRange else { return }

        let previousAssets = assets(in: prefetchedAssetRange)
        let newAssets = assets(in: range)

        if !previousAssets.isEmpty {
            let options = thumbnailRequestOptions()
            imageManager.stopCachingImages(
                for: previousAssets,
                targetSize: Constants.thumbnailTargetSize,
                contentMode: .aspectFill,
                options: options
            )
        }

        if !newAssets.isEmpty {
            let options = thumbnailRequestOptions()
            imageManager.startCachingImages(
                for: newAssets,
                targetSize: Constants.thumbnailTargetSize,
                contentMode: .aspectFill,
                options: options
            )
        }

        prefetchedAssetRange = range
    }

    private func fetchAlbumPage(limit: Int, previousCount: Int = 0) -> Range<Int> {
        let options = PHFetchOptions()
        options.fetchLimit = limit
        options.includeHiddenAssets = false
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        isLoadingPage = true
        album = PHAsset.fetchAssets(with: .image, options: options)
        fetchedAlbum = limit
        ensureModelsCapacity(for: album.count)
        isLoadingPage = false

        guard album.count > previousCount else { return 0..<0 }
        canLoadMorePages = album.count == limit

        return previousCount..<album.count
    }

    func getImage(image: PickedImageModel, for asset: PHAsset, completionHandler: @escaping (UIImage?) -> Void) {
        let requestOptions = PHImageRequestOptions()
        requestOptions.isNetworkAccessAllowed = true
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.version = .current
        requestOptions.isSynchronous = false

        outputImage = nil
        imageManager.requestImageDataAndOrientation(for: asset, options: requestOptions) { [weak self] data, _, _, _ in
            guard let self else { return }
            guard image.identifier == asset.localIdentifier else { return }

            DispatchQueue.main.async {
                guard let data, let fullResolutionImage = UIImage(data: data) else {
                    completionHandler(nil)
                    return
                }

                self.outputImage = fullResolutionImage
                completionHandler(fullResolutionImage)
            }
        }
    }

    func loadImage(for asset: PHAsset, index: Int) {
        let identifier = asset.localIdentifier
        let requestOptions = thumbnailRequestOptions()

        imageManager.requestImage(
            for: asset,
            targetSize: Constants.thumbnailTargetSize,
            contentMode: .aspectFill,
            options: requestOptions
        ) { [weak self] result, _ in
            guard let self else { return }
            guard identifier == asset.localIdentifier else { return }

            guard index < self.models.count else { return }
            if let image = result {
                DispatchQueue.main.async {
                    self.saveImageArray(index: index, image: image, identifier: identifier)
                }
            }
        }
    }

    func saveImageArray(index: Int, image: UIImage, identifier: String?) {
        ensureModelsCapacity(for: index + 1)

        var model = PickedImageModel()
        model.image = image
        model.index = index
        model.identifier = identifier
        model.isSelected = models[index].isSelected
        models[index] = model
    }

    func ensureModelsCapacity(for count: Int) {
        if models.count < count {
            let missingCount = count - models.count
            models.append(contentsOf: Array(repeating: PickedImageModel(), count: missingCount))
        }
    }

    private func assets(in range: Range<Int>) -> [PHAsset] {
        guard range.lowerBound < range.upperBound else { return [] }
        return range.compactMap { index in
            guard index >= 0 && index < album.count else { return nil }
            return album.object(at: index)
        }
    }

    private func thumbnailRequestOptions() -> PHImageRequestOptions {
        let requestOptions = PHImageRequestOptions()
        requestOptions.isNetworkAccessAllowed = true
        requestOptions.deliveryMode = .fastFormat
        requestOptions.resizeMode = .fast
        requestOptions.isSynchronous = false
        return requestOptions
    }
}
