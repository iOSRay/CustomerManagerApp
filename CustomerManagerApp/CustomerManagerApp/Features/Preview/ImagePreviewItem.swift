import UIKit
import Kingfisher

struct ImagePreviewItem {
    enum Source {
        case image(UIImage)
        case url(URL)
    }

    let source: Source
    let placeholder: UIImage?
    let processor: ImageProcessor?
    let initialWidthRatio: CGFloat?
    let cacheKey: String?
    let prefersFitHeight: Bool
    let accessibilityLabel: String?

    init(image: UIImage,
         placeholder: UIImage? = nil,
         processor: ImageProcessor? = nil,
         initialWidthRatio: CGFloat? = nil,
         cacheKey: String? = nil,
         prefersFitHeight: Bool = false,
         accessibilityLabel: String? = nil) {
        self.source = .image(image)
        self.placeholder = placeholder
        self.processor = processor
        self.initialWidthRatio = initialWidthRatio
        self.cacheKey = cacheKey
        self.prefersFitHeight = prefersFitHeight
        self.accessibilityLabel = accessibilityLabel
    }

    init(url: URL,
         placeholder: UIImage? = nil,
         processor: ImageProcessor? = nil,
         initialWidthRatio: CGFloat? = nil,
         cacheKey: String? = nil,
         prefersFitHeight: Bool = false,
         accessibilityLabel: String? = nil) {
        self.source = .url(url)
        self.placeholder = placeholder
        self.processor = processor
        self.initialWidthRatio = initialWidthRatio
        self.cacheKey = cacheKey
        self.prefersFitHeight = prefersFitHeight
        self.accessibilityLabel = accessibilityLabel
    }
}
