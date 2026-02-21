import XCTest
import UIKit

@testable import _024_MacC_M4_6princess

final class FilterImageCacheTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        FilterImageCache.shared.removeAll()
    }

    func testCacheReturnsSameInstanceForSameUUID() {
        let cache = FilterImageCache.shared
        let uuid = UUID()
        let image = makeTestImage()

        cache.setImage(image, for: uuid)
        let first = cache.image(for: uuid)
        let second = cache.image(for: uuid)

        XCTAssertNotNil(first)
        XCTAssertNotNil(second)
        XCTAssertEqual(first === second, true)
    }

    func testCacheDecodesAndStoresFromData() {
        let cache = FilterImageCache.shared
        let uuid = UUID()
        let image = makeTestImage()
        let data = image.pngData()!

        let decoded = cache.image(for: uuid, data: data)
        let cached = cache.image(for: uuid)

        XCTAssertNotNil(decoded)
        XCTAssertNotNil(cached)
        XCTAssertEqual(decoded === cached, true)
    }

    private func makeTestImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8))
        return renderer.image { context in
            UIColor.systemPink.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
    }
}
