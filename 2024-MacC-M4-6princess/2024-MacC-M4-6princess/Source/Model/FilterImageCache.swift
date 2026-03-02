import UIKit

final class FilterImageCache {
    static let shared = FilterImageCache()

    private let cache = NSCache<NSString, UIImage>()
    private let lock = NSLock()

    private init() {
        cache.countLimit = 256
        cache.totalCostLimit = 80 * 1024 * 1024
    }

    func image(for id: UUID) -> UIImage? {
        let key = id.uuidString as NSString
        return cache.object(forKey: key)
    }

    func image(for id: UUID, data: Data?) -> UIImage? {
        let key = id.uuidString as NSString

        if let cached = cache.object(forKey: key) {
            return cached
        }

        guard let data else {
            return nil
        }

        guard let image = SafeImageDecoder.decodeImage(from: data) else {
            return nil
        }

        setImage(image, for: id)
        return image
    }

    func setImage(_ image: UIImage, for id: UUID) {
        let key = id.uuidString as NSString
        let cost = estimateImageCost(image)

        lock.lock()
        defer { lock.unlock() }
        cache.setObject(image, forKey: key, cost: cost)
    }

    func removeImage(for id: UUID) {
        let key = id.uuidString as NSString
        lock.lock()
        defer { lock.unlock() }
        cache.removeObject(forKey: key)
    }

    func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAllObjects()
    }

    private func estimateImageCost(_ image: UIImage) -> Int {
        guard let cgImage = image.cgImage else {
            return 0
        }
        return cgImage.bytesPerRow * cgImage.height
    }
}
