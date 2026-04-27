//
//  ImagePreviewViewController.swift
//  PixHairApp
//
//  图片全屏预览：接近系统相册的使用体验（分页、缩放、下拉关闭、顶部/底部栏）。
//

import UIKit
import Kingfisher

final class ImagePreviewViewController: UIViewController, UIViewControllerTransitioningDelegate {
    private let backgroundView = UIView()
    private let topBar = UIView()
    private let closeButton = UIButton(type: .system)
    private let titleLabel = UILabel()

    private let items: [ImagePreviewItem]
    private let initialIndex: Int
    private weak var singleOriginView: UIView?
    private let originViewProvider: ((Int) -> UIView?)?

    private var didInitialScroll = false
    private var isChromeHidden = false
    private var pageIndexDuringScroll: Int?

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.isPagingEnabled = true
        cv.showsHorizontalScrollIndicator = false
        cv.showsVerticalScrollIndicator = false
        cv.backgroundColor = .clear
        cv.decelerationRate = .fast
        // 预览下拉关闭时不需要 ScrollView 的橡皮筋/滚动反馈
        cv.bounces = false
        cv.alwaysBounceVertical = false
        cv.alwaysBounceHorizontal = false
        cv.isDirectionalLockEnabled = true
        cv.dataSource = self
        cv.delegate = self
        cv.register(ImagePreviewPageCell.self, forCellWithReuseIdentifier: ImagePreviewPageCell.reuseID)
        return cv
    }()

    private lazy var panToDismiss: UIPanGestureRecognizer = {
        let g = UIPanGestureRecognizer(target: self, action: #selector(handlePanToDismiss(_:)))
        g.delegate = self
        return g
    }()

    // MARK: - Init
    init(items: [ImagePreviewItem], initialIndex: Int = 0, originViewProvider: ((Int) -> UIView?)? = nil) {
        self.items = items
        self.initialIndex = max(0, min(initialIndex, max(0, items.count - 1)))
        self.originViewProvider = originViewProvider
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .custom
        transitioningDelegate = self
    }

    convenience init(image: UIImage, originView: UIView? = nil) {
        self.init(items: [ImagePreviewItem(image: image)], initialIndex: 0, originViewProvider: nil)
        self.singleOriginView = originView
    }

    /// 高清预览：通过 URL 直载原图，可选传入缩略图作为占位与转场来源（兼容旧调用）。
    convenience init(imageURL: URL,
                     placeholder: UIImage? = nil,
                     originView: UIView? = nil,
                     processor: ImageProcessor? = nil,
                     initialWidthRatio: CGFloat? = nil,
                     cacheKey: String? = nil,
                     prefersFitHeight: Bool = false) {
        let item = ImagePreviewItem(url: imageURL,
                                    placeholder: placeholder,
                                    processor: processor,
                                    initialWidthRatio: initialWidthRatio,
                                    cacheKey: cacheKey,
                                    prefersFitHeight: prefersFitHeight)
        self.init(items: [item], initialIndex: 0, originViewProvider: nil)
        self.singleOriginView = originView
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        backgroundView.backgroundColor = UIColor.black.withAlphaComponent(1.0)
        backgroundView.alpha = 0
        view.addSubview(backgroundView)
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        view.addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        setupChrome()
        view.addGestureRecognizer(panToDismiss)
        updateChromeTitle()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            let size = view.bounds.size
            if layout.itemSize != size {
                layout.itemSize = size
                layout.invalidateLayout()
            }
        }
        guard didInitialScroll == false else { return }
        didInitialScroll = true
        let indexPath = IndexPath(item: initialIndex, section: 0)
        if items.indices.contains(initialIndex) {
            collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: false)
        }
        updateChromeTitle()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 0.18) { self.backgroundView.alpha = 1 }
    }

    // MARK: - Convenience
    static func present(from presenter: UIViewController, image: UIImage, originView: UIView? = nil) {
        let vc = ImagePreviewViewController(image: image, originView: originView)
        presenter.present(vc, animated: true)
    }

    static func present(from presenter: UIViewController, imageURL: URL, placeholder: UIImage? = nil, originView: UIView? = nil) {
        let vc = ImagePreviewViewController(imageURL: imageURL, placeholder: placeholder, originView: originView)
        presenter.present(vc, animated: true)
    }

    static func present(from presenter: UIViewController,
                        items: [ImagePreviewItem],
                        initialIndex: Int = 0,
                        originViewProvider: ((Int) -> UIView?)? = nil) {
        let vc = ImagePreviewViewController(items: items, initialIndex: initialIndex, originViewProvider: originViewProvider)
        presenter.present(vc, animated: true)
    }

    // MARK: - Chrome
    private func setupChrome() {
        topBar.backgroundColor = .clear
        view.addSubview(topBar)
        topBar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 56)
        ])

        if let img = UIImage(systemName: "xmark") {
            closeButton.setImage(img, for: .normal)
        } else {
            closeButton.setTitle("关闭", for: .normal)
        }
        closeButton.tintColor = .white
        closeButton.addTarget(self, action: #selector(onTapClose), for: .touchUpInside)
        topBar.addSubview(closeButton)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            closeButton.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -16),
            closeButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44)
        ])

        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        topBar.addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -8),
            titleLabel.centerYAnchor.constraint(equalTo: topBar.centerYAnchor)
        ])

        // 底部操作条（分享/复制）按当前产品需求移除，保持纯预览体验。
    }

    private func setChromeHidden(_ hidden: Bool, animated: Bool) {
        isChromeHidden = hidden
        let alpha: CGFloat = hidden ? 0 : 1
        if animated {
            UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut]) {
                self.topBar.alpha = alpha
            }
        } else {
            topBar.alpha = alpha
        }
        setNeedsStatusBarAppearanceUpdate()
    }

    private func toggleChrome() {
        setChromeHidden(!isChromeHidden, animated: true)
    }

    private func updateChromeTitle() {
        let count = items.count
        guard count > 1 else {
            titleLabel.text = ""
            return
        }
        let index = pageIndexDuringScroll ?? currentIndex
        titleLabel.text = "\(index + 1)/\(count)"
    }

    private func updateCurrentPageIndexIfNeeded() {
        let width = collectionView.bounds.width
        guard width > 0 else { return }
        let rawIndex = Int(round(collectionView.contentOffset.x / width))
        let clampedIndex = max(0, min(items.count - 1, rawIndex))
        guard pageIndexDuringScroll != clampedIndex else { return }
        pageIndexDuringScroll = clampedIndex
        updateChromeTitle()
    }

    // MARK: - Actions
    @objc private func onTapClose() {
        dismiss(animated: true)
    }

    @objc private func handlePanToDismiss(_ g: UIPanGestureRecognizer) {
        guard currentZoomScale <= 1.01 else { return }
        let translation = g.translation(in: view)
        let progress = max(0, min(1, translation.y / 300))
        switch g.state {
        case .changed:
            let scale = 1 - progress * 0.2
            let t = CGAffineTransform(translationX: translation.x, y: translation.y).scaledBy(x: scale, y: scale)
            collectionView.transform = t
            topBar.transform = t
            backgroundView.alpha = 1 - progress
        case .ended, .cancelled:
            let velocity = g.velocity(in: view).y
            if progress > 0.35 || velocity > 800 {
                UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut]) {
                    let offY = max(self.view.bounds.height, translation.y + self.view.bounds.height * 0.7)
                    let t = CGAffineTransform(translationX: translation.x, y: offY).scaledBy(x: 0.86, y: 0.86)
                    self.collectionView.transform = t
                    self.topBar.transform = t
                    self.backgroundView.alpha = 0
                } completion: { _ in
                    self.dismiss(animated: false)
                }
            } else {
                UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseOut]) {
                    self.collectionView.transform = .identity
                    self.topBar.transform = .identity
                    self.backgroundView.alpha = 1
                }
            }
        default:
            break
        }
    }

    // MARK: - State
    private var currentIndex: Int {
        guard let indexPath = currentIndexPath else { return initialIndex }
        return indexPath.item
    }

    private var currentIndexPath: IndexPath? {
        let center = CGPoint(x: collectionView.bounds.midX + collectionView.contentOffset.x,
                             y: collectionView.bounds.midY + collectionView.contentOffset.y)
        return collectionView.indexPathForItem(at: center)
    }

    private var currentZoomScale: CGFloat {
        guard let indexPath = currentIndexPath,
              let cell = collectionView.cellForItem(at: indexPath) as? ImagePreviewPageCell else {
            return 1.0
        }
        return cell.zoomView.zoomScale
    }

    private func currentPreviewImage() -> UIImage? {
        if let indexPath = currentIndexPath,
           let cell = collectionView.cellForItem(at: indexPath) as? ImagePreviewPageCell,
           let img = cell.zoomView.currentImage {
            return img
        }
        guard items.indices.contains(currentIndex) else { return nil }
        switch items[currentIndex].source {
        case .image(let img):
            return img
        case .url:
            return items[currentIndex].placeholder
        }
    }

    private func originViewForTransition(at index: Int) -> UIView? {
        if let originViewProvider { return originViewProvider(index) }
        return singleOriginView
    }

    // MARK: - Status bar
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
    override var prefersStatusBarHidden: Bool { isChromeHidden }
}

extension ImagePreviewViewController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === panToDismiss else { return true }
        guard currentZoomScale <= 1.01 else { return false }
        let v = panToDismiss.velocity(in: view)
        return abs(v.y) > abs(v.x)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // 下拉关闭手势需要独占，避免与 UICollectionView/内部 ScrollView 同时滚动导致“自带滚动效果”。
        if gestureRecognizer === panToDismiss || otherGestureRecognizer === panToDismiss { return false }
        return true
    }
}

extension ImagePreviewViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { items.count }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ImagePreviewPageCell.reuseID, for: indexPath)
        guard let c = cell as? ImagePreviewPageCell else { return cell }
        let item = items[indexPath.item]
        c.zoomView.onSingleTap = { [weak self] in self?.toggleChrome() }
        c.zoomView.onZoomScaleChanged = { [weak self] scale in
            guard let self else { return }
            self.collectionView.isScrollEnabled = scale <= 1.01
        }
        c.zoomView.onImageChanged = nil
        c.zoomView.configure(with: item)
        return c
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView === collectionView else { return }
        collectionView.isScrollEnabled = true
        updateCurrentPageIndexIfNeeded()
        updateChromeTitle()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard scrollView === collectionView else { return }
        if !decelerate {
            collectionView.isScrollEnabled = true
            updateCurrentPageIndexIfNeeded()
            updateChromeTitle()
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === collectionView else { return }
        updateCurrentPageIndexIfNeeded()
    }
}

// MARK: - Custom transition (zooming from originView)
extension ImagePreviewViewController {
    var previewedImageForTransition: UIImage { currentPreviewImage() ?? UIImage() }
    var originViewForCurrentIndex: UIView? { originViewForTransition(at: currentIndex) }

    static func aspectFitRect(for imageSize: CGSize, in bounds: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, bounds.width > 0, bounds.height > 0 else { return bounds }
        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let w = imageSize.width * scale
        let h = imageSize.height * scale
        let x = bounds.midX - w / 2
        let y = bounds.midY - h / 2
        return CGRect(x: x, y: y, width: w, height: h)
    }

    // MARK: UIViewControllerTransitioningDelegate
    func animationController(forPresented presented: UIViewController,
                             presenting: UIViewController,
                             source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        ImagePreviewPresentAnimator()
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        ImagePreviewDismissAnimator()
    }
}

final class ImagePreviewPresentAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval { 0.22 }

    func animateTransition(using ctx: UIViewControllerContextTransitioning) {
        guard let toVC = ctx.viewController(forKey: .to) as? ImagePreviewViewController else { return ctx.completeTransition(true) }
        let container = ctx.containerView
        let toView = toVC.view!
        toView.frame = container.bounds
        toView.alpha = 0
        container.addSubview(toView)

        let image = toVC.previewedImageForTransition
        let endRect = ImagePreviewViewController.aspectFitRect(for: image.size, in: container.bounds)
        let startRect: CGRect = toVC.originViewForCurrentIndex.flatMap { view in
            view.superview?.convert(view.frame, to: container) ?? container.bounds
        } ?? endRect

        let snapshot = UIImageView(image: image)
        snapshot.contentMode = .scaleAspectFill
        snapshot.clipsToBounds = true
        snapshot.frame = startRect
        snapshot.layer.cornerRadius = (toVC.originViewForCurrentIndex as? UIImageView)?.layer.cornerRadius ?? 0
        container.addSubview(snapshot)

        toVC.view.layoutIfNeeded()
        toVC.view.backgroundColor = .clear
        toVC.view.isHidden = true

        UIView.animate(withDuration: transitionDuration(using: ctx), delay: 0, options: [.curveEaseOut]) {
            snapshot.frame = endRect
            snapshot.layer.cornerRadius = 0
            toView.alpha = 1
        } completion: { _ in
            toVC.view.isHidden = false
            snapshot.removeFromSuperview()
            ctx.completeTransition(true)
        }
    }
}

final class ImagePreviewDismissAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval { 0.2 }

    func animateTransition(using ctx: UIViewControllerContextTransitioning) {
        guard let fromVC = ctx.viewController(forKey: .from) as? ImagePreviewViewController else { return ctx.completeTransition(true) }
        let container = ctx.containerView
        let fromView = fromVC.view!

        let image = fromVC.previewedImageForTransition
        let startRect = ImagePreviewViewController.aspectFitRect(for: image.size, in: container.bounds)
        let endRect: CGRect = fromVC.originViewForCurrentIndex.flatMap { view in
            view.superview?.convert(view.frame, to: container) ?? container.bounds
        } ?? startRect

        let snapshot = UIImageView(image: image)
        snapshot.contentMode = .scaleAspectFill
        snapshot.clipsToBounds = true
        snapshot.frame = startRect
        container.addSubview(snapshot)
        fromView.isHidden = true

        UIView.animate(withDuration: transitionDuration(using: ctx), delay: 0, options: [.curveEaseOut]) {
            snapshot.frame = endRect
            snapshot.layer.cornerRadius = (fromVC.originViewForCurrentIndex as? UIImageView)?.layer.cornerRadius ?? 0
            container.backgroundColor = .clear
        } completion: { _ in
            snapshot.removeFromSuperview()
            ctx.completeTransition(true)
        }
    }
}
