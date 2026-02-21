import SwiftUI
import Photos

class PhotosPickerViewModel: ObservableObject {
    
    @Published var models: [PickedImageModel] = []
    @Published var selectedIndex: Int = -1
    @Published var outputImage: UIImage?
    @Published var messageOpacity: Double = 1
    @Published var currentIndex: Int = 0
    @Published var fetchedAlbum: Int = 60
    @Published var firstAppear: Bool = true
    
    private let imageManager = PHCachingImageManager()
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
    
    func fetchAlbum() {
        let options = PHFetchOptions()
        options.fetchLimit = fetchedAlbum
        options.includeHiddenAssets = false
        options.includeAssetSourceTypes = [.typeUserLibrary]
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        album = PHAsset.fetchAssets(with: .image, options: options)
        ensureModelsCapacity(for: album.count)
    }
    
    func getImage(image: PickedImageModel, for asset: PHAsset, completionHandler: @escaping (UIImage?) -> Void) {
        let requestOptions = PHImageRequestOptions()
        requestOptions.isNetworkAccessAllowed = true
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.resizeMode = .exact
        requestOptions.isSynchronous = false
        
        outputImage = nil
        imageManager.requestImage(
            for: asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFill,
            options: requestOptions
        ) { [self] result, _ in
            guard image.identifier == asset.localIdentifier else { return }
            DispatchQueue.main.async {
                if let image = result {
                    self.outputImage = image
                    completionHandler(image)
                } else {
                    completionHandler(nil)
                }
            }
        }
    }
    
    func loadImage(for asset: PHAsset, size: CGSize, index: Int) {
        let identifier = asset.localIdentifier
        let requestOptions = PHImageRequestOptions()
        requestOptions.isNetworkAccessAllowed = true
        requestOptions.isSynchronous = false
        requestOptions.deliveryMode = .fastFormat
        requestOptions.resizeMode = .fast
//        requestOptions.version = .original
        
        imageManager.requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: requestOptions) {
            [weak self] result, _ in
            guard let self else { return }
            guard identifier == asset.localIdentifier else { return }
            
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
}
