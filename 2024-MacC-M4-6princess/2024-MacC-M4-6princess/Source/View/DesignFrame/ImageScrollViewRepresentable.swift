import SwiftUI
import UIKit

struct ImageScrollViewRepresentable: UIViewRepresentable {
    private enum Layout {
        static let numberOfColumns = 3
        static let spacing: CGFloat = 5
        static let itemSize = CGSize(width: UIScreen.main.bounds.width * 0.32, height: UIScreen.main.bounds.height * 0.2)
    }
    
    var images: [PickedImageModel]
    var onScrollToBottom: () -> Void
    var onVisibleIndexChange: (Int) -> Void
    var onImageTap: (Int) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onScrollToBottom: onScrollToBottom, onImageTap: onImageTap, onVisibleIndexChange: onVisibleIndexChange)
    }
    
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.alwaysBounceVertical = true
        scrollView.alwaysBounceHorizontal = false

        let contentView = UIView()
        contentView.tag = 1000
        scrollView.addSubview(contentView)
        updateContent(contentView, with: images, context: context)
        scrollView.contentSize = contentView.frame.size

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        guard let contentView = scrollView.viewWithTag(1000) else { return }
        updateContent(contentView, with: images, context: context)
        scrollView.contentSize = contentView.frame.size
    }

    private func itemOrigin(at index: Int) -> CGPoint {
        let row = index / Layout.numberOfColumns
        let col = index % Layout.numberOfColumns
        return CGPoint(
            x: CGFloat(col) * (Layout.itemSize.width + Layout.spacing),
            y: CGFloat(row) * (Layout.itemSize.height + Layout.spacing)
        )
    }

    private func updateContent(_ contentView: UIView, with images: [PickedImageModel], context: Context) {
        let validTagSet = Set(images.map(\.index))

        // 삭제된 셀 정리
        contentView.subviews.forEach { imageView in
            if imageView.tag != 1000, !validTagSet.contains(imageView.tag) {
                imageView.removeFromSuperview()
            }
        }

        for model in images where model.index >= 0 {
            guard let imageView = contentView.viewWithTag(model.index) as? UIImageView else {
                let newImageView = UIImageView(image: model.image)
                newImageView.contentMode = .scaleAspectFill
                newImageView.clipsToBounds = true
                newImageView.isUserInteractionEnabled = true
                newImageView.tag = model.index

                let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.imageTapped(_:)))
                newImageView.addGestureRecognizer(tap)
                contentView.addSubview(newImageView)

                continue
            }

            imageView.image = model.image
        }

        for model in images where model.index >= 0 {
            if let imageView = contentView.viewWithTag(model.index) as? UIImageView {
                imageView.frame = CGRect(origin: itemOrigin(at: model.index), size: Layout.itemSize)
            }
        }

        let rows = (images.count + Layout.numberOfColumns - 1) / Layout.numberOfColumns
        let contentWidth = CGFloat(Layout.numberOfColumns) * (Layout.itemSize.width + Layout.spacing) - Layout.spacing
        let contentHeight = CGFloat(rows) * (Layout.itemSize.height + Layout.spacing) - Layout.spacing
        contentView.frame = CGRect(x: 0, y: 0, width: contentWidth, height: max(contentHeight, 0.01))
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        var onScrollToBottom: () -> Void
        var onImageTap: (Int) -> Void
        var onVisibleIndexChange: (Int) -> Void
        private var isNearBottomSent = false

        init(onScrollToBottom: @escaping () -> Void,
             onImageTap: @escaping (Int) -> Void,
             onVisibleIndexChange: @escaping (Int) -> Void) {
            self.onScrollToBottom = onScrollToBottom
            self.onImageTap = onImageTap
            self.onVisibleIndexChange = onVisibleIndexChange
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let offsetY = scrollView.contentOffset.y
            let contentHeight = scrollView.contentSize.height
            let visibleHeight = scrollView.frame.height

            let itemHeight = UIScreen.main.bounds.height * 0.2 + Layout.spacing
            let rowHeight = max(itemHeight, 1)
            let row = Int((offsetY + visibleHeight / 2) / rowHeight)
            let visibleIndex = max(0, row * Layout.numberOfColumns)
            onVisibleIndexChange(visibleIndex)

            let shouldLoadMore = offsetY > contentHeight - visibleHeight - 100
            if shouldLoadMore {
                if !isNearBottomSent {
                    isNearBottomSent = true
                    onScrollToBottom()
                }
            } else {
                isNearBottomSent = false
            }
        }

        @objc func imageTapped(_ sender: UITapGestureRecognizer) {
            if let imageView = sender.view as? UIImageView {
                onImageTap(imageView.tag)
            }
        }
    }
}
