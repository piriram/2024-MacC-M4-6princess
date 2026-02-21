import SwiftUI

@MainActor
protocol ImagePipelining {
    func displayScale(for image: UIImage, screenWidth: CGFloat, aspectRatio: CGFloat) -> CGFloat
    func renderImage<Content: View>(content: Content, scale: CGFloat) -> UIImage?
}

extension ImagePipelining {
    func displayScale(for image: UIImage, screenWidth: CGFloat) -> CGFloat {
        displayScale(for: image, screenWidth: screenWidth, aspectRatio: 4/3)
    }
}

@MainActor
final class ImagePipelineService: ImagePipelining {
    func displayScale(for image: UIImage, screenWidth: CGFloat, aspectRatio: CGFloat = 4/3) -> CGFloat {
        var scale: CGFloat = image.size.height / (screenWidth * aspectRatio)

        if image.size.width / scale > screenWidth || image.size.width >= image.size.height {
            scale = image.size.width / screenWidth
        }

        return scale
    }

    func renderImage<Content: View>(content: Content, scale: CGFloat) -> UIImage? {
        let renderer = ImageRenderer(content: content)
        renderer.scale = scale
        return renderer.uiImage
    }
}
