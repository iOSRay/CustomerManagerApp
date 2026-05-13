import UIKit
import Kingfisher

struct Rotate90CWImageProcessor: ImageProcessor {
    let identifier = "com.customermanager.imageprocessor.rotate90cw"

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

        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: height,
            height: width,
            bitsPerComponent: cgImage.bitsPerComponent,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: cgImage.bitmapInfo.rawValue
        ) else {
            return self
        }

        context.translateBy(x: CGFloat(height), y: 0)
        context.rotate(by: .pi / 2)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let rotated = context.makeImage() else { return self }
        return UIImage(cgImage: rotated, scale: scale, orientation: .up)
    }
}
