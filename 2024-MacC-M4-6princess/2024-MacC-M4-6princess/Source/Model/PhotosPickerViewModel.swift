import SwiftUI
import Photos
import UIKit

enum PhotoImportQualityOption: String, CaseIterable, Identifiable {
    case original
    case high
    case standard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .original: return "원본"
        case .high: return "고화질"
        case .standard: return "표준"
        }
    }

    var maxLongEdge: CGFloat? {
        switch self {
        case .original:
            return nil
        case .high:
            return 4096
        case .standard:
            return 2048
        }
    }
}

class PhotosPickerViewModel: ObservableObject {
    private enum Constants {
        static let pageSize = 60
        static let gridItemWidthRatio: CGFloat = 0.32
        static let gridItemHeightRatio: CGFloat = 0.2
        static let prefetchMargin = 30
        static let qualityOptionKey = "photo.import.quality.option"

        static var thumbnailPointSize: CGSize {
            CGSize(width: UIScreen.main.bounds.width * gridItemWidthRatio,
                   height: UIScreen.main.bounds.height * gridItemHeightRatio)
        }

        static var thumbnailPixelTargetSize: CGSize {
            let scale = UIScreen.main.scale
            return CGSize(width: ceil(thumbnailPointSize.width * scale),
                          height: ceil(thumbnailPointSize.height * scale))
        }
    }

    @Published var models: [PickedImageModel] = []
    @Published var selectedIndex: Int = -1
    @Published var outputImage: UIImage?
    @Published var messageOpacity: Double = 1
    @Published var fetchedAlbum: Int = Constants.pageSize
    @Published var firstAppear: Bool = true
    @Published var canLoadMorePages: Bool = false
    @Published var selectedImportQuality: PhotoImportQualityOption = .original

    private let imageManager = PHCachingImageManager()
    private var isLoadingPage: Bool = false
    private var prefetchedAssetRange = 0..<0
    
    var album: PHFetchResult<PHAsset> = PHFetchResult<PHAsset>()
    var viewSize: CGSize = .zero
    var offset: CGFloat = 0
    var originOffset: CGFloat = 0
    var isCheckedOriginOffset: Bool = false

    init() {
        selectedImportQuality = Self.loadQualityOption()
    }

    func updateImportQuality(_ option: PhotoImportQualityOption, userDefaults: UserDefaults = .standard) {
        selectedImportQuality = option
        userDefaults.set(option.rawValue, forKey: Constants.qualityOptionKey)
    }

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
                targetSize: Constants.thumbnailPixelTargetSize,
                contentMode: .aspectFill,
                options: options
            )
        }

        if !newAssets.isEmpty {
            let options = thumbnailRequestOptions()
            imageManager.startCachingImages(
                for: newAssets,
                targetSize: Constants.thumbnailPixelTargetSize,
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
        requestOptions.version = .original
        requestOptions.resizeMode = .none
        requestOptions.isSynchronous = false

        outputImage = nil
        imageManager.requestImageDataAndOrientation(for: asset, options: requestOptions) { [weak self] data, _, _, info in
            guard let self else { return }
            guard image.identifier == asset.localIdentifier else { return }

            DispatchQueue.main.async {
                if let data, let fullResolutionImage = UIImage(data: data) {
                    let processed = self.processedImage(from: fullResolutionImage)
                    print("[PhotoImport] quality=\(self.selectedImportQuality.rawValue) original=\(Int(fullResolutionImage.size.width))x\(Int(fullResolutionImage.size.height)) output=\(Int(processed.size.width))x\(Int(processed.size.height))")
                    self.outputImage = processed
                    completionHandler(processed)
                    return
                }

                let errorDescription = (info?[PHImageErrorKey] as? Error)?.localizedDescription ?? "unknown"
                let inCloud = (info?[PHImageResultIsInCloudKey] as? Bool) ?? false
                print("[PhotoImport] requestImageDataAndOrientation failed id=\(asset.localIdentifier) inCloud=\(inCloud) error=\(errorDescription)")

                self.loadImageFromContentEditingInput(asset: asset) { fallbackImage in
                    DispatchQueue.main.async {
                        guard image.identifier == asset.localIdentifier else { return }

                        if let fallbackImage {
                            let processed = self.processedImage(from: fallbackImage)
                            print("[PhotoImport] contentEditingInput fallback success original=\(Int(fallbackImage.size.width))x\(Int(fallbackImage.size.height)) output=\(Int(processed.size.width))x\(Int(processed.size.height))")
                            self.outputImage = processed
                            completionHandler(processed)
                        } else {
                            print("[PhotoImport] contentEditingInput fallback failed id=\(asset.localIdentifier)")
                            completionHandler(nil)
                        }
                    }
                }
            }
        }
    }

    func loadImage(for asset: PHAsset, index: Int) {
        let identifier = asset.localIdentifier
        let requestOptions = thumbnailRequestOptions()

        imageManager.requestImage(
            for: asset,
            targetSize: Constants.thumbnailPixelTargetSize,
            contentMode: .aspectFill,
            options: requestOptions
        ) { [weak self] result, info in
            guard let self else { return }
            guard identifier == asset.localIdentifier else { return }
            guard index < self.models.count else { return }

            if let image = result {
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                let resultPixelSize = image.pixelSize
                let targetPixelSize = Constants.thumbnailPixelTargetSize
                let lowResolutionThreshold: CGFloat = 0.75
                let isLowResolution = resultPixelSize.width < (targetPixelSize.width * lowResolutionThreshold)
                    || resultPixelSize.height < (targetPixelSize.height * lowResolutionThreshold)
                
                DispatchQueue.main.async {
                    self.saveImageArray(index: index, image: image, identifier: identifier)
                }

                if isLowResolution && !isDegraded {
                    self.loadThumbnailFromImageData(asset: asset, index: index, identifier: identifier, reason: "lowResolution")
                }
                return
            }

            let errorDescription = (info?[PHImageErrorKey] as? Error)?.localizedDescription ?? "unknown"
            let inCloud = (info?[PHImageResultIsInCloudKey] as? Bool) ?? false

            self.loadThumbnailFromImageData(asset: asset, index: index, identifier: identifier, reason: "requestImageFailed")
        }
    }

    private func loadThumbnailFromImageData(asset: PHAsset, index: Int, identifier: String, reason: String) {
        let requestOptions = thumbnailRequestOptions()

        imageManager.requestImageDataAndOrientation(for: asset, options: requestOptions) { [weak self] data, _, _, fallbackInfo in
            guard let self else { return }
            guard identifier == asset.localIdentifier else { return }
            guard index < self.models.count else { return }

            if let data, let full = UIImage(data: data) {
                let thumbnail = full.thumbnailImage(targetSize: Constants.thumbnailPointSize, contentMode: .scaleAspectFill)
                
                DispatchQueue.main.async {
                    self.saveImageArray(index: index, image: thumbnail, identifier: identifier)
                }
                return
            }

            let fallbackError = (fallbackInfo?[PHImageErrorKey] as? Error)?.localizedDescription ?? "unknown"

            self.loadImageFromContentEditingInput(asset: asset) { fallbackImage in
                guard identifier == asset.localIdentifier else { return }
                guard index < self.models.count else { return }

                DispatchQueue.main.async {
                    if let fallbackImage {
                        let thumbnail = fallbackImage.thumbnailImage(targetSize: Constants.thumbnailPointSize, contentMode: .scaleAspectFill)

                        self.saveImageArray(index: index, image: thumbnail, identifier: identifier)
                    } else {
                        self.saveImageArray(index: index,
                                            image: self.unavailablePlaceholderImage(),
                                            identifier: identifier)
                    }
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

    private func processedImage(from source: UIImage) -> UIImage {
        guard let maxLongEdge = selectedImportQuality.maxLongEdge else {
            return source
        }
        return source.resized(maxLongEdge: maxLongEdge) ?? source
    }

    private func loadImageFromContentEditingInput(asset: PHAsset, completion: @escaping (UIImage?) -> Void) {
        let options = PHContentEditingInputRequestOptions()
        options.isNetworkAccessAllowed = true

        asset.requestContentEditingInput(with: options) { input, _ in
            guard let url = input?.fullSizeImageURL,
                  let data = try? Data(contentsOf: url),
                  let image = UIImage(data: data) else {
                completion(nil)
                return
            }
            completion(image)
        }
    }

    private func unavailablePlaceholderImage() -> UIImage {
        if let symbol = UIImage(systemName: "icloud.slash") {
            return symbol
        }
        return UIImage()
    }

    private static func loadQualityOption(userDefaults: UserDefaults = .standard) -> PhotoImportQualityOption {
        guard let raw = userDefaults.string(forKey: Constants.qualityOptionKey),
              let value = PhotoImportQualityOption(rawValue: raw) else {
            return .original
        }
        return value
    }

    private func thumbnailRequestOptions() -> PHImageRequestOptions {
        let requestOptions = PHImageRequestOptions()
        requestOptions.isNetworkAccessAllowed = true
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.resizeMode = .exact
        requestOptions.version = .original
        requestOptions.isSynchronous = false
        return requestOptions
    }
}

private extension UIImage {
    var pixelSize: CGSize {
        CGSize(width: size.width * scale, height: size.height * scale)
    }

    func resized(maxLongEdge: CGFloat) -> UIImage? {
        let longEdge = max(size.width, size.height)
        guard longEdge > maxLongEdge, longEdge > 0 else {
            return self
        }

        let ratio = maxLongEdge / longEdge
        let targetSize = CGSize(width: floor(size.width * ratio), height: floor(size.height * ratio))
        guard targetSize.width > 0, targetSize.height > 0 else { return self }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)

        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    func thumbnailImage(targetSize: CGSize, contentMode: UIView.ContentMode = .scaleAspectFill) -> UIImage {
        guard targetSize.width > 0, targetSize.height > 0 else { return self }

        let sourceSize = size
        guard sourceSize.width > 0, sourceSize.height > 0 else { return self }

        let widthRatio = targetSize.width / sourceSize.width
        let heightRatio = targetSize.height / sourceSize.height
        let scale = contentMode == .scaleAspectFill ? max(widthRatio, heightRatio) : min(widthRatio, heightRatio)

        let drawSize = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
        let origin = CGPoint(x: (targetSize.width - drawSize.width) / 2,
                             y: (targetSize.height - drawSize.height) / 2)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = UIScreen.main.scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)

        return renderer.image { _ in
            UIColor.black.setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: targetSize)).fill()
            draw(in: CGRect(origin: origin, size: drawSize))
        }
    }
}
