//
//  PicSequencePlayerView.swift
//  PixHairApp
//
//  读取 Bundle 子目录中的图片序列并以 30fps 播放。
//  约束：
//  - 不做无缝循环：播放到末尾后回到第一帧并停止。
//  - 不支持倒放/拖动进度。
//

import UIKit

final class PicSequencePlayerView: UIView {
    enum State: Equatable {
        case idle
        case playing
        case paused
    }

    private let imageView = UIImageView()
    private let playButton = UIButton(type: .system)
    private var displayLink: CADisplayLink?
    private var lastTickTimestamp: CFTimeInterval?
    private var accumulated: CFTimeInterval = 0

    private var cache: PicFrameCache?
    private(set) var state: State = .idle {
        didSet {
            if state != oldValue { onStateChange?(state) }
            updatePlayButtonAppearance()
        }
    }
    private var currentIndex: Int = 0
    private var fps: Int = 30
    private var prefetchAhead: Int = 12
    private var prefetchBehind: Int = 2
    private var playbackEnabled: Bool = false
    private var frameNumberByIndex: [Int] = []

    /// Offsets the rendered frame inside the view without changing layout constraints.
    /// Useful when a frame sequence has extra transparent padding on one side.
    var imageOffset: CGPoint = .zero {
        didSet { applyImageOffset() }
    }

    var onStateChange: ((State) -> Void)?
    var onPlaybackEnded: (() -> Void)?
    /// 帧号回调：默认取资源文件名末尾的数字后缀（如 rollAndRotate_100 -> 100）；解析失败则回退为 index。
    var onFrameIndexChange: ((_ frameNumber: Int, _ totalFrames: Int) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyImageOffset()
    }

    deinit {
        // 不能在 deinit 中调用 stop()：
        // stop() 会触发 setImage(at:) -> cache.loadImage(...) { [weak self] ... }
        // 在对象析构过程中创建 weak 引用会触发：
        // "Cannot form weak reference ... is in the process of deallocation."
        stopDisplayLink()
        cache = nil
        onStateChange = nil
        onPlaybackEnded = nil
        onFrameIndexChange = nil
    }

    func configure(
        subdirectory: String = "pic",
        fileExtension: String = "png",
        filenamePrefix: String? = nil,
        placeholder: UIImage? = nil,
        fps: Int = 30,
        cacheCountLimit: Int = 60,
        contentMode: UIView.ContentMode = .scaleAspectFit
    ) {
        self.fps = max(1, min(60, fps))
        imageView.contentMode = contentMode
        playbackEnabled = true

        let urls = PicSequenceProvider.loadImageURLs(subdirectory: subdirectory,
                                                     fileExtension: fileExtension,
                                                     filenamePrefix: filenamePrefix)
        guard !urls.isEmpty else {
            // 还没放入对应序列帧时也要能“看见组件已加载”：先显示占位图。
            setStaticImage(placeholder)
            return
        }
        frameNumberByIndex = urls.enumerated().map { idx, url in
            let name = url.deletingPathExtension().lastPathComponent
            return numericSuffix(of: name) ?? idx
        }
        cache = PicFrameCache(urls: urls, cacheCountLimit: cacheCountLimit)
        currentIndex = 0
        state = .idle
        lastTickTimestamp = nil
        accumulated = 0
        emitFrameIndexChangeIfPossible()

        cache?.loadImage(at: 0) { [weak self] _, image in
            guard let self else { return }
            DispatchQueue.main.async {
                self.imageView.image = image
            }
        }
        prefetchAroundCurrent()
    }

    func play() {
        guard playbackEnabled else { return }
        guard let cache, cache.count > 0 else { return }
        if state == .playing { return }
        state = .playing
        startDisplayLinkIfNeeded()
    }

    func pause() {
        guard playbackEnabled else { return }
        guard state == .playing else { return }
        state = .paused
        stopDisplayLink()
    }

    func stop() {
        stopDisplayLink()
        state = .idle
        currentIndex = 0
        lastTickTimestamp = nil
        accumulated = 0
        setImage(at: 0)
        emitFrameIndexChangeIfPossible()
    }

    func setStaticImage(_ image: UIImage?) {
        stopDisplayLink()
        playbackEnabled = false
        cache = nil
        state = .idle
        currentIndex = 0
        lastTickTimestamp = nil
        accumulated = 0
        imageView.image = image
    }

    private func setupUI() {
        backgroundColor = .clear
        imageView.backgroundColor = .clear
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        playButton.tintColor = .white
        playButton.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        playButton.layer.cornerRadius = 28
        playButton.clipsToBounds = true
        playButton.accessibilityLabel = "播放"
        playButton.addTarget(self, action: #selector(handlePlayButtonTap), for: .touchUpInside)
        addSubview(playButton)
        playButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            playButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            playButton.widthAnchor.constraint(equalToConstant: 56),
            playButton.heightAnchor.constraint(equalToConstant: 56)
        ])

        applyImageOffset()
        updatePlayButtonAppearance()
    }

    private func applyImageOffset() {
        if imageOffset == .zero {
            imageView.transform = .identity
        } else {
            imageView.transform = CGAffineTransform(translationX: imageOffset.x, y: imageOffset.y)
        }
    }

    private func updatePlayButtonAppearance() {
        guard playbackEnabled else {
            playButton.isHidden = true
            return
        }
        let imageName: String
        let hidden: Bool
        switch state {
        case .playing:
            imageName = "pause.fill"
            hidden = true
        case .paused, .idle:
            imageName = "play.fill"
            hidden = false
        }
        let img = UIImage(systemName: imageName)?.withRenderingMode(.alwaysTemplate)
        playButton.setImage(img, for: .normal)
        playButton.isHidden = hidden
    }

    @objc private func handlePlayButtonTap() {
        switch state {
        case .playing:
            pause()
        case .paused, .idle:
            play()
        }
    }

    private func startDisplayLinkIfNeeded() {
        if displayLink != nil { return }
        lastTickTimestamp = nil
        accumulated = 0
        let link = CADisplayLink(target: self, selector: #selector(onDisplayLinkTick(_:)))
        if #available(iOS 15.0, *) {
            link.preferredFrameRateRange = CAFrameRateRange(minimum: Float(fps), maximum: Float(fps), preferred: Float(fps))
        } else {
            link.preferredFramesPerSecond = fps
        }
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func onDisplayLinkTick(_ link: CADisplayLink) {
        guard state == .playing else { return }
        guard let cache, cache.count > 0 else { return }

        let ts = link.timestamp
        if let last = lastTickTimestamp {
            accumulated += max(0, ts - last)
        }
        lastTickTimestamp = ts

        let frameDuration = 1.0 / Double(fps)
        guard accumulated >= frameDuration else { return }
        accumulated = accumulated.truncatingRemainder(dividingBy: frameDuration)

        let nextIndex = currentIndex + 1
        if nextIndex >= cache.count {
            currentIndex = 0
            setImage(at: 0)
            pause()
            emitFrameIndexChangeIfPossible()
            onPlaybackEnded?()
            return
        }

        currentIndex = nextIndex
        setImage(at: currentIndex)
        emitFrameIndexChangeIfPossible()
        prefetchAroundCurrent()
    }

    private func emitFrameIndexChangeIfPossible() {
        guard let cache, cache.count > 0 else { return }
        let idx = currentIndex
        let frameNumber = (idx >= 0 && idx < frameNumberByIndex.count) ? frameNumberByIndex[idx] : idx
        let total = cache.count
        if Thread.isMainThread {
            onFrameIndexChange?(frameNumber, total)
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.onFrameIndexChange?(frameNumber, total)
            }
        }
    }

    private func numericSuffix(of filename: String) -> Int? {
        guard !filename.isEmpty else { return nil }
        var digits: [UnicodeScalar] = []
        for s in filename.unicodeScalars.reversed() {
            if CharacterSet.decimalDigits.contains(s) {
                digits.append(s)
            } else {
                break
            }
        }
        guard !digits.isEmpty else { return nil }
        let str = String(String.UnicodeScalarView(digits.reversed()))
        return Int(str)
    }

    private func setImage(at index: Int) {
        guard let cache else { return }
        if let cached = cache.image(at: index) {
            imageView.image = cached
            return
        }
        cache.loadImage(at: index) { [weak self] _, image in
            guard let self else { return }
            DispatchQueue.main.async {
                if self.currentIndex == index {
                    self.imageView.image = image
                }
            }
        }
    }

    private func prefetchAroundCurrent() {
        guard let cache else { return }
        let start = max(0, currentIndex - prefetchBehind)
        let end = min(cache.count - 1, currentIndex + prefetchAhead)
        guard start <= end else { return }
        cache.prefetch(indices: Array(start...end))
    }
}
