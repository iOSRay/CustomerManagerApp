import UIKit
import Kingfisher

final class ZoomableImagePreviewView: UIView, UIScrollViewDelegate {
    var onSingleTap: (() -> Void)?
    var onZoomScaleChanged: ((CGFloat) -> Void)?
    var onImageChanged: ((UIImage?) -> Void)?

    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private let loadingView = UIActivityIndicatorView(style: .large)

    private var item: ImagePreviewItem?
    private var image: UIImage = UIImage()
    private var didConfigureZoom = false
    private var configuredImageSize: CGSize = .zero
    private var configuredViewBounds: CGSize = .zero
    private var didUserInteractZoom: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    var currentImage: UIImage? {
        let size = image.size
        return (size.width > 0 && size.height > 0) ? image : nil
    }

    var zoomScale: CGFloat { scrollView.zoomScale }

    func configure(with item: ImagePreviewItem) {
        self.item = item
        didUserInteractZoom = false
        didConfigureZoom = false
        configuredImageSize = .zero
        configuredViewBounds = .zero

        imageView.accessibilityLabel = item.accessibilityLabel
        imageView.isAccessibilityElement = item.accessibilityLabel != nil

        switch item.source {
        case .image(let image):
            setImage(image)
        case .url(let url):
            setPlaceholderImage(item.placeholder)
            loadOriginalImage(from: url, item: item)
        }
    }

    func resetZoom() {
        didUserInteractZoom = false
        configureZoomIfNeeded(force: true)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        configureZoomIfNeeded()
    }

    // MARK: - Setup
    private func setup() {
        isOpaque = false
        backgroundColor = .clear

        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 3.0
        scrollView.delegate = self
        scrollView.alwaysBounceVertical = false
        scrollView.alwaysBounceHorizontal = false
        // 预览未放大时不需要“拖拽滚动”的弹性效果（下拉关闭由外部手势接管）
        scrollView.bounces = false
        scrollView.backgroundColor = .clear
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        scrollView.addSubview(imageView)

        addSubview(loadingView)
        loadingView.hidesWhenStopped = true
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            loadingView.centerXAnchor.constraint(equalTo: centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap(_:)))
        singleTap.require(toFail: doubleTap)
        addGestureRecognizer(doubleTap)
        addGestureRecognizer(singleTap)

        updateScrollPanEnabled()
    }

    // MARK: - Actions
    @objc private func handleSingleTap(_ g: UITapGestureRecognizer) {
        onSingleTap?()
    }

    @objc private func handleDoubleTap(_ g: UITapGestureRecognizer) {
        let minScale = scrollView.minimumZoomScale
        let maxScale = scrollView.maximumZoomScale
        let isZoomedIn = scrollView.zoomScale > (minScale + 0.01)
        let zoomInScale = min(maxScale, max(2.0, minScale * 2.5))
        let newScale: CGFloat = isZoomedIn ? minScale : zoomInScale
        let point = g.location(in: imageView)
        zoom(to: point, scale: newScale, animated: true)
    }

    private func zoom(to point: CGPoint, scale: CGFloat, animated: Bool) {
        let bounds = imageView.bounds
        let w = bounds.width / scale
        let h = bounds.height / scale
        let x = max(min(point.x - w / 2, bounds.width - w), 0)
        let y = max(min(point.y - h / 2, bounds.height - h), 0)
        let rect = CGRect(x: x, y: y, width: w, height: h)
        scrollView.zoom(to: rect, animated: animated)
    }

    // MARK: - UIScrollViewDelegate
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        didUserInteractZoom = true
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        updateScrollInsets()
        updateScrollPanEnabled()
        onZoomScaleChanged?(scrollView.zoomScale)
    }

    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        updateScrollInsets()
        updateScrollPanEnabled()
        onZoomScaleChanged?(scrollView.zoomScale)
    }

    // MARK: - Image loading
    private func setPlaceholderImage(_ placeholder: UIImage?) {
        if let placeholder {
            setImage(placeholder)
        } else {
            setImage(UIImage())
        }
    }

    private func setImage(_ image: UIImage) {
        self.image = image
        imageView.image = image
        onImageChanged?(currentImage)
        configureZoomIfNeeded(force: true)
        updateScrollPanEnabled()
    }

    private func loadOriginalImage(from url: URL, item: ImagePreviewItem) {
        loadingView.startAnimating()
        var options: KingfisherOptionsInfo = [
            .cacheOriginalImage,
            .backgroundDecode,
            .transition(.fade(0.15))
        ]
        if let processor = item.processor {
            options.append(.processor(processor))
        }

        let resource: KF.ImageResource? = {
            guard let key = item.cacheKey?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty else { return nil }
            return KF.ImageResource(downloadURL: url, cacheKey: key)
        }()

        let apply: @MainActor @Sendable (Result<RetrieveImageResult, KingfisherError>) -> Void = { [weak self] result in
            guard let self else { return }
            self.loadingView.stopAnimating()
            if case let .success(value) = result {
                self.image = value.image
                self.imageView.image = value.image
                self.onImageChanged?(self.currentImage)
                self.configureZoomIfNeeded(force: false)
            } else {
                self.onImageChanged?(self.currentImage)
            }
        }

        if let resource {
            imageView.kf.setImage(with: resource, placeholder: item.placeholder, options: options, completionHandler: apply)
        } else {
            imageView.kf.setImage(with: url, placeholder: item.placeholder, options: options, completionHandler: apply)
        }
    }

    // MARK: - Layout helpers
    private func configureZoomIfNeeded(force: Bool = false) {
        guard let item else { return }
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0, bounds.width > 0, bounds.height > 0 else { return }

        let viewBounds = bounds.size
        let boundsChanged = viewBounds != configuredViewBounds
        let imageChanged = imageSize != configuredImageSize
        let isUserZoomed = didUserInteractZoom

        if force || !didConfigureZoom || imageChanged || (boundsChanged && !isUserZoomed) {
            imageView.frame = CGRect(origin: .zero, size: imageSize)
            scrollView.contentSize = imageSize

            let fitScale = min(viewBounds.width / imageSize.width, viewBounds.height / imageSize.height)
            let fitMinScale = min(1.0, fitScale)
            let heightScale = viewBounds.height / imageSize.height
            let targetScale: CGFloat? = {
                guard let r = item.initialWidthRatio, r > 0, r < 1 else { return nil }
                return (viewBounds.width * r) / imageSize.width
            }()

            let initialScale: CGFloat = {
                if let targetScale, targetScale > 0 { return targetScale }
                if item.prefersFitHeight { return min(1.0, heightScale) }
                return fitMinScale
            }()

            let minScale = min(fitMinScale, initialScale)
            let maxScale: CGFloat = {
                if item.initialWidthRatio != nil {
                    return max(3.0, min(60.0, max(minScale * 6.0, initialScale * 1.2)))
                }
                return max(3.0, min(12.0, minScale * 6.0))
            }()

            scrollView.minimumZoomScale = minScale
            scrollView.maximumZoomScale = maxScale

            let shouldUpdateZoomForBoundsChange = (item.initialWidthRatio != nil) && boundsChanged && !isUserZoomed
            if force || !didConfigureZoom || (imageChanged && !isUserZoomed) || shouldUpdateZoomForBoundsChange {
                scrollView.zoomScale = min(maxScale, max(minScale, initialScale))
            } else if scrollView.zoomScale < minScale {
                scrollView.zoomScale = minScale
            } else if scrollView.zoomScale > maxScale {
                scrollView.zoomScale = maxScale
            }

            didConfigureZoom = true
            configuredImageSize = imageSize
            configuredViewBounds = viewBounds
        }

        updateScrollInsets()
        updateScrollPanEnabled()
    }

    private func updateScrollInsets() {
        let boundsSize = scrollView.bounds.size
        let contentSize = scrollView.contentSize
        let insetX = max(0, (boundsSize.width - contentSize.width) / 2)
        let insetY = max(0, (boundsSize.height - contentSize.height) / 2)
        scrollView.contentInset = UIEdgeInsets(top: insetY, left: insetX, bottom: insetY, right: insetX)
    }

    private func updateScrollPanEnabled() {
        // 未放大时不允许拖动内容（避免“自带滚动效果”），放大后才允许拖动查看细节。
        let enabled = scrollView.zoomScale > (scrollView.minimumZoomScale + 0.01)
        if scrollView.panGestureRecognizer.isEnabled != enabled {
            scrollView.panGestureRecognizer.isEnabled = enabled
        }
        // 放大后允许拖动，但仍不需要边界“橡皮筋”反馈
        scrollView.bounces = false
        if !enabled {
            // 复位到居中位置
            let x = -scrollView.contentInset.left
            let y = -scrollView.contentInset.top
            scrollView.setContentOffset(CGPoint(x: x, y: y), animated: false)
        }
    }
}
