import XCTest
import SwiftUI
@testable import _024_MacC_M4_6princess

final class ImagePipelineServiceTests: XCTestCase {
    @MainActor
    func testDisplayScaleUsesWidthForLandscapeImage() {
        let sut = ImagePipelineService()
        let resized = UIGraphicsImageRenderer(size: CGSize(width: 800, height: 400)).image { _ in
            UIColor.white.setFill()
            UIBezierPath(rect: CGRect(x: 0, y: 0, width: 800, height: 400)).fill()
        }

        let scale = sut.displayScale(for: resized, screenWidth: 400)

        XCTAssertEqual(scale, 2.0, accuracy: 0.001)
    }

    @MainActor
    func testDisplayScaleUsesHeightForPortraitImage() {
        let sut = ImagePipelineService()
        let portrait = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 900)).image { _ in
            UIColor.white.setFill()
            UIBezierPath(rect: CGRect(x: 0, y: 0, width: 300, height: 900)).fill()
        }

        let scale = sut.displayScale(for: portrait, screenWidth: 300)

        XCTAssertGreaterThan(scale, 1.0)
        XCTAssertEqual(scale, portrait.size.height / (300 * (4.0/3.0)), accuracy: 0.001)
    }

    @MainActor
    func testRenderImageReturnsImageForSimpleView() {
        let sut = ImagePipelineService()
        let content = Color.red.frame(width: 100, height: 100)

        let rendered = sut.renderImage(content: content, scale: 1)

        XCTAssertNotNil(rendered)
    }
}
