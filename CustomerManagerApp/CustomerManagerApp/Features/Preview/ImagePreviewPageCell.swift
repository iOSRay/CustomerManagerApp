import UIKit

final class ImagePreviewPageCell: UICollectionViewCell {
    static let reuseID = "ImagePreviewPageCell"

    let zoomView = ZoomableImagePreviewView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .clear
        contentView.addSubview(zoomView)
        zoomView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            zoomView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            zoomView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            zoomView.topAnchor.constraint(equalTo: contentView.topAnchor),
            zoomView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func prepareForReuse() {
        super.prepareForReuse()
        zoomView.onSingleTap = nil
        zoomView.onZoomScaleChanged = nil
        zoomView.onImageChanged = nil
        zoomView.configure(with: ImagePreviewItem(image: UIImage()))
    }
}
