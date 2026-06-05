import UIKit
import Kingfisher

struct Rotate90CWImageProcessor: ImageProcessor {
    let identifier = "com.customermanager.imageprocessor.rotate90cw.metadata.v2"

    func process(item: ImageProcessItem, options: KingfisherParsedOptionsInfo) -> KFCrossPlatformImage? {
        let image: UIImage?
        switch item {
        case let .image(value):
            image = value
        case let .data(data):
            image = DefaultImageProcessor.default.process(item: .data(data), options: options)
        }

        guard let image else { return nil }
        return image.rotated90CW()
    }
}

private extension UIImage {
    func rotated90CW() -> UIImage {
        guard let cgImage else { return self }

        let rotatedOrientation: UIImage.Orientation = switch imageOrientation {
        case .up: .right
        case .right: .down
        case .down: .left
        case .left: .up
        case .upMirrored: .rightMirrored
        case .rightMirrored: .downMirrored
        case .downMirrored: .leftMirrored
        case .leftMirrored: .upMirrored
        @unknown default: .right
        }
        return UIImage(cgImage: cgImage, scale: scale, orientation: rotatedOrientation)
    }
}
