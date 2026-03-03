import XCTest
import UIKit
@testable import _024_MacC_M4_6princess

final class PhotosPickerViewModelTests: XCTestCase {
    func testSaveImageArrayCreatesMissingModels() {
        let sut = PhotosPickerViewModel()

        let image = makeTestImage()
        sut.saveImageArray(index: 3, image: image, identifier: "photo-3")

        XCTAssertEqual(sut.models.count, 4)
        XCTAssertEqual(sut.models[3].index, 3)
        XCTAssertEqual(sut.models[3].identifier, "photo-3")
        XCTAssertNotNil(sut.models[3].image)
    }

    func testSaveImageArrayReplacesExistingCellByIndex() {
        let sut = PhotosPickerViewModel()

        let image1 = makeTestImage()
        let image2 = makeTestImage()
        sut.saveImageArray(index: 1, image: image1, identifier: "photo-1")
        sut.saveImageArray(index: 1, image: image2, identifier: "photo-1-new")

        XCTAssertEqual(sut.models.count, 2)
        XCTAssertEqual(sut.models[1].identifier, "photo-1-new")
        XCTAssertEqual(sut.models[1].index, 1)
        XCTAssertNotNil(sut.models[1].image)
    }

    func testSaveImageArrayPreservesExistingSelectionState() {
        let sut = PhotosPickerViewModel()
        var selectedModel = PickedImageModel()
        selectedModel.isSelected = true
        sut.models = [selectedModel]

        let image = makeTestImage()
        sut.saveImageArray(index: 0, image: image, identifier: "photo-selected")

        XCTAssertTrue(sut.models[0].isSelected)
    }

    private func makeTestImage() -> UIImage {
        let size = CGSize(width: 2, height: 2)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.randomTint.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

private extension UIColor {
    static var randomTint: UIColor {
        UIColor(
            red: CGFloat.random(in: 0...1),
            green: CGFloat.random(in: 0...1),
            blue: CGFloat.random(in: 0...1),
            alpha: 1
        )
    }
}
