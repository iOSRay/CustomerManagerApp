import SwiftUI
import UIKit
import Kingfisher
import Refresh

private enum AppPage {
    case home
    case records
    case detail
}

private enum StatsPane {
    case all
    case quick
    case custom
}

private enum QuickRange: CaseIterable {
    case h24
    case h48
    case h72
    case week

    var title: String {
        switch self {
        case .h24: return "24h"
        case .h48: return "48h"
        case .h72: return "72h"
        case .week: return "1周"
        }
    }

    var statsPreset: UsageStatsQuery.Preset {
        switch self {
        case .h24: return .h24
        case .h48: return .h48
        case .h72: return .h72
        case .week: return .d7
        }
    }
}

private enum FilterField: Hashable {
    case store
    case city
    case contact
}

private struct DetailFormulaItem: Identifiable {
    let id = UUID()
    let degree: String
    let part: String
    let formula: String
    let ratio: String
    let referenceId: String
    let delta: String
    let lab1: String
    let lab2: String
    let useAltSwatch: Bool
    let previewAssets: [ScanRecordPreviewImage]
}

private extension UIView {
    var owningViewController: UIViewController? {
        sequence(first: self as UIResponder?, next: { $0?.next }).first { $0 is UIViewController } as? UIViewController
    }
}

private extension UIApplication {
    static func topViewController(
        base: UIViewController? = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
    ) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            return topViewController(base: tab.selectedViewController)
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }
}

private extension ScanRecordPreviewImage {
    func asPreviewItem(placeholder: UIImage?) -> ImagePreviewItem? {
        guard let url else { return nil }
        return ImagePreviewItem(
            url: url,
            placeholder: placeholder,
            processor: rotates90CW ? Rotate90CWImageProcessor() : nil,
            initialWidthRatio: initialWidthRatio.map { CGFloat($0) },
            cacheKey: cacheKey,
            prefersFitHeight: prefersFitHeight,
            accessibilityLabel: accessibilityLabel
        )
    }
}

private final class DetailPreviewImageTileView: UIView {
    private let placeholderView = UIView()
    private let imageView = UIImageView()
    private var previewItems: [ImagePreviewItem] = []
    private var previewIndex: Int = 0
    private var currentAsset: ScanRecordPreviewImage?
    private var lastLoadedCacheKey: String?
    private var lastLoadedSize: CGSize = .zero

    private lazy var tapRecognizer: UITapGestureRecognizer = {
        let gesture = UITapGestureRecognizer(target: self, action: #selector(handleTapPreview))
        return gesture
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        layer.cornerRadius = 2
        clipsToBounds = true
        isUserInteractionEnabled = true
        addGestureRecognizer(tapRecognizer)

        addSubview(placeholderView)
        placeholderView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            placeholderView.leadingAnchor.constraint(equalTo: leadingAnchor),
            placeholderView.trailingAnchor.constraint(equalTo: trailingAnchor),
            placeholderView.topAnchor.constraint(equalTo: topAnchor),
            placeholderView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
    }

    func configure(
        assets: [ScanRecordPreviewImage],
        displayIndex: Int,
        alt: Bool
    ) {
        previewIndex = displayIndex
        let colors: [UIColor] = alt
            ? [UIColor(red: 0.85, green: 0.70, blue: 0.50, alpha: 1), UIColor(red: 0.80, green: 0.63, blue: 0.43, alpha: 1)]
            : [UIColor(red: 0.88, green: 0.77, blue: 0.58, alpha: 1), UIColor(red: 0.83, green: 0.69, blue: 0.46, alpha: 1)]
        placeholderView.layer.sublayers?.removeAll()
        let gradient = CAGradientLayer()
        gradient.frame = bounds
        gradient.colors = colors.map(\.cgColor)
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)
        placeholderView.layer.insertSublayer(gradient, at: 0)
        placeholderView.layer.borderWidth = 1
        placeholderView.layer.borderColor = UIColor(red: 0.80, green: 0.72, blue: 0.61, alpha: 1).cgColor

        let nextAsset = assets.indices.contains(displayIndex) ? assets[displayIndex] : nil
        previewItems = assets.compactMap { $0.asPreviewItem(placeholder: nil) }
        tapRecognizer.isEnabled = !previewItems.isEmpty

        if currentAsset != nextAsset {
            currentAsset = nextAsset
            lastLoadedCacheKey = nil
            lastLoadedSize = .zero
            imageView.image = nil
            imageView.kf.cancelDownloadTask()
        }

        loadImageIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        placeholderView.layer.sublayers?.first?.frame = placeholderView.bounds
        loadImageIfNeeded()
    }

    private func loadImageIfNeeded() {
        guard let currentAsset, let currentURL = currentAsset.url else { return }
        let targetSize = bounds.size
        guard targetSize.width >= 8, targetSize.height >= 8 else { return }

        let cacheKey = currentAsset.cacheKey?.isEmpty == false
            ? currentAsset.cacheKey!
            : currentURL.absoluteString
        guard cacheKey != lastLoadedCacheKey || targetSize != lastLoadedSize else { return }

        lastLoadedCacheKey = cacheKey
        lastLoadedSize = targetSize

        let resizedSize = currentAsset.rotates90CW
            ? CGSize(width: targetSize.height, height: targetSize.width)
            : targetSize
        let processor: any ImageProcessor = {
            let resize = ResizingImageProcessor(referenceSize: resizedSize, mode: .aspectFill)
            if currentAsset.rotates90CW {
                return resize |> Rotate90CWImageProcessor()
            }
            return resize
        }()
        let resource = KF.ImageResource(downloadURL: currentURL, cacheKey: cacheKey)
        imageView.kf.setImage(
            with: resource,
            placeholder: nil,
            options: [
                .processor(processor),
                .scaleFactor(UIScreen.main.scale),
                .cacheOriginalImage,
                .backgroundDecode,
                .retryStrategy(DelayRetryStrategy(maxRetryCount: 2, retryInterval: .seconds(1)))
            ]
        )
    }

    @objc private func handleTapPreview() {
        guard !previewItems.isEmpty else { return }
        guard let presenter = owningViewController ?? UIApplication.topViewController() else { return }

        let vc = ImagePreviewViewController(
            items: previewItems,
            initialIndex: min(previewIndex, max(0, previewItems.count - 1)),
            originViewProvider: { [weak self] _ in self?.imageView }
        )
        presenter.present(vc, animated: true)
    }
}

private struct DetailPreviewImageTile: UIViewRepresentable {
    let assets: [ScanRecordPreviewImage]
    let displayIndex: Int
    let alt: Bool

    func makeUIView(context: Context) -> DetailPreviewImageTileView {
        DetailPreviewImageTileView()
    }

    func updateUIView(_ uiView: DetailPreviewImageTileView, context: Context) {
        uiView.configure(assets: assets, displayIndex: displayIndex, alt: alt)
    }
}

private final class DetailMainPhotoImageView: UIView {
    private let imageView = UIImageView()
    private var imageURL: URL?
    private var lastLoadedCacheKey: String?
    private var lastLoadedSize: CGSize = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    func configure(url: URL?) {
        guard imageURL != url else {
            loadImageIfNeeded()
            return
        }

        imageURL = url
        lastLoadedCacheKey = nil
        lastLoadedSize = .zero
        imageView.image = nil
        imageView.kf.cancelDownloadTask()
        loadImageIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        loadImageIfNeeded()
    }

    private func loadImageIfNeeded() {
        guard let imageURL else { return }
        let targetSize = bounds.size
        guard targetSize.width >= 8, targetSize.height >= 8 else { return }

        let cacheKey = SignedImageCacheKey.make(for: imageURL)
        guard cacheKey != lastLoadedCacheKey || targetSize != lastLoadedSize else { return }

        lastLoadedCacheKey = cacheKey
        lastLoadedSize = targetSize

        let processor = DownsamplingImageProcessor(
            size: CGSize(
                width: max(1, ceil(targetSize.width * 1.25)),
                height: max(1, ceil(targetSize.height * 1.25))
            )
        )
        let resource = KF.ImageResource(downloadURL: imageURL, cacheKey: cacheKey)
        imageView.kf.setImage(
            with: resource,
            placeholder: nil,
            options: [
                .processor(processor),
                .scaleFactor(UIScreen.main.scale),
                .cacheOriginalImage,
                .backgroundDecode,
                .retryStrategy(DelayRetryStrategy(maxRetryCount: 2, retryInterval: .seconds(1)))
            ]
        )
    }
}

private struct DetailMainPhotoImage: UIViewRepresentable {
    let url: URL?

    func makeUIView(context: Context) -> DetailMainPhotoImageView {
        DetailMainPhotoImageView()
    }

    func updateUIView(_ uiView: DetailMainPhotoImageView, context: Context) {
        uiView.configure(url: url)
    }
}

struct DashboardView: View {
    private static let listTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    private static let filterFieldDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    @StateObject private var dashboardViewModel: DashboardViewModel
    @StateObject private var scanViewModel: ScanRecordListViewModel

    @State private var page: AppPage = .home
    @State private var statsPane: StatsPane = .all
    @State private var quickRange: QuickRange = .h24
    @State private var showFilterPopup = false
    @State private var selectedRecord: ScanRecord?
    @State private var customStart = Date().addingTimeInterval(-24 * 3600)
    @State private var customEnd = Date()
    @State private var recordStart = Date().addingTimeInterval(-24 * 3600)
    @State private var recordEnd = Date()
    @State private var usesRecordDateFilter = false
    @State private var visibleRecordCount = 20
    @State private var isLoadingMoreRecords = false
    @State private var isRefreshingRecords = false
    @State private var isLoadingSelectedRecordDetail = false
    @State private var recordReloadTask: Task<Void, Never>?
    @FocusState private var filterFocusedField: FilterField?

    private let recordPageSize = 20
    private let detailContentInset: CGFloat = 10
    private let detailCardInnerInset: CGFloat = 10
    private let detailPhotoWidth: CGFloat = 160

    init(dashboardViewModel: DashboardViewModel, scanViewModel: ScanRecordListViewModel) {
        _dashboardViewModel = StateObject(wrappedValue: dashboardViewModel)
        _scanViewModel = StateObject(wrappedValue: scanViewModel)
    }

    var body: some View {
        GeometryReader { geo in
            let sideInset: CGFloat = 0

            ZStack {
                Color(red: 0.95, green: 0.97, blue: 0.98).ignoresSafeArea()

                contentLayer
                    .padding(.horizontal, sideInset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .background(Color(red: 0.95, green: 0.97, blue: 0.98))
                    .zIndex(0)

                topBarOverlay
                    .padding(.horizontal, sideInset)

                if showFilterPopup, page == .records {
                    overlay
                        .zIndex(200)
                    filterPopup(maxWidth: min(520, geo.size.width - sideInset * 2 - 20))
                        .zIndex(201)
                }
            }
            .task {
                await dashboardViewModel.load()
            }
            .loadingHUD(isShowingRequestHUD)
            .onChange(of: showFilterPopup) { _, isPresented in
                if !isPresented {
                    filterFocusedField = nil
                }
            }
        }
    }

    private var topBar: some View {
        HStack {
            backButton
            Spacer()
            Text(pageTitle)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color(red: 0.09, green: 0.16, blue: 0.23))
            Spacer()
            actionButton
        }
        .padding(.horizontal, 10)
        .frame(height: 44)
        .contentShape(Rectangle())
        .background(.white)
        .zIndex(100)
    }

    @ViewBuilder
    private var backButton: some View {
        if page == .home {
            Color.clear.frame(width: 34, height: 30)
        } else {
            Button(action: onTapBack) {
                Text("‹")
                    .font(.system(size: 22, weight: .bold))
                    .frame(width: 34, height: 30)
                    .foregroundStyle(Color(red: 0.09, green: 0.16, blue: 0.23))
                    .background(.white)
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(red: 0.89, green: 0.91, blue: 0.94), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .zIndex(101)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch page {
        case .home:
            topActionButton(title: "记录") {
                page = .records
                Task { await loadRecordsIfNeeded() }
            }
        case .records:
            topActionButton(title: "筛选") {
                showFilterPopup = true
            }
        case .detail:
            Color.clear.frame(width: 56, height: 30)
        }
    }

    private func topActionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 56, height: 30)
                .foregroundStyle(Color(red: 0.09, green: 0.16, blue: 0.23))
                .background(.white)
                .contentShape(Rectangle())
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(red: 0.89, green: 0.91, blue: 0.94), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .zIndex(101)
    }

    private var topBarOverlay: some View {
        VStack(spacing: 0) {
            topBar
            Spacer(minLength: 0)
        }
        .zIndex(100)
    }

    private var contentLayer: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 44)
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        switch page {
        case .home:
            homeContent
        case .records:
            recordsContent
        case .detail:
            detailContent
        }
    }

    private var homeContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                segmented(
                    options: ["卖出至今", "过去时段", "任意时间"],
                    selectedIndex: statsPaneIndex,
                    onTap: { index in
                        guard index != statsPaneIndex else { return }
                        statsPane = [StatsPane.all, .quick, .custom][index]
                        Task { await reloadStatsForCurrentSelection() }
                    }
                )

                switch statsPane {
                case .all:
                    statsCardAll
                case .quick:
                    statsCardQuick
                case .custom:
                    statsCardCustom
                }
            }
            .padding(10)
        }
    }

    private var statsCardAll: some View {
        statsCardCurrent(showSoldDevices: true)
    }

    private var statsCardQuick: some View {
        VStack(alignment: .leading, spacing: 8) {
            segmented(
                options: QuickRange.allCases.map(\.title),
                selectedIndex: QuickRange.allCases.firstIndex(of: quickRange) ?? 0,
                onTap: { index in
                    let selectedRange = QuickRange.allCases[index]
                    guard selectedRange != quickRange else { return }
                    quickRange = selectedRange
                    Task { await dashboardViewModel.load(.preset(quickRange.statsPreset)) }
                }
            )

            statsCardCurrent(showSoldDevices: false)
        }
    }

    private var statsCardCustom: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 10) {
                    DatePicker("", selection: $customStart, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .padding(8)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(red: 0.89, green: 0.91, blue: 0.94), lineWidth: 1)
                        }

                    DatePicker("", selection: $customEnd, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .padding(8)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(red: 0.89, green: 0.91, blue: 0.94), lineWidth: 1)
                        }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                popupButton("计算", primary: true) {
                    Task { await dashboardViewModel.load(.custom(start: customStart, end: customEnd)) }
                }
                    .frame(minWidth: 72)
            }

            statsCardCurrent(showSoldDevices: false)
        }
    }

    private func statsCardCurrent(showSoldDevices: Bool) -> some View {
        Group {
            if case let .loaded(stats) = dashboardViewModel.state {
                kpiGridCard(items: statsItems(stats, showSoldDevices: showSoldDevices))
            } else if case .loading = dashboardViewModel.state {
                kpiGridCard(items: [])
            } else if case let .failed(message) = dashboardViewModel.state {
                card {
                    Text(message)
                        .font(.system(size: 14))
                        .foregroundStyle(Color(red: 0.42, green: 0.48, blue: 0.54))
                }
            } else {
                kpiGridCard(items: [])
            }
        }
    }

    private func statsItems(_ stats: DashboardStats, showSoldDevices: Bool) -> [(String, String)] {
        var items: [(String, String)] = []
        if showSoldDevices {
            items.append(("卖出设备总数", "\(stats.soldDevices)"))
        }
        items.append(contentsOf: [
            ("总使用次数", "\(stats.totalUsages)"),
            (showSoldDevices ? "至少使用过1次设备数" : "使用设备数", "\(stats.activeDevices)"),
            ("使用率", "\(Int((stats.usageRate * 100).rounded()))%")
        ])
        return items
    }

    private var recordsContent: some View {
        ScrollView(showsIndicators: false) {
            RefreshHeader(refreshing: $isRefreshingRecords) {
                refreshRecordsFromHeader()
            } label: { progress in
                refreshHeaderLabel(progress: progress)
            }

            VStack(alignment: .leading, spacing: 8) {
                if case .loading = scanViewModel.state {
                    EmptyView()
                } else if case let .failed(message) = scanViewModel.state {
                    plainCard {
                        Text(message)
                            .font(.system(size: 14))
                            .foregroundStyle(Color(red: 0.42, green: 0.48, blue: 0.54))
                    }
                } else {
                    ForEach(displayedRecords) { record in
                        Button {
                            openDetail(record)
                        } label: {
                            VStack(alignment: .leading, spacing: 7) {
                                HStack(spacing: 10) {
                                    Text(record.deviceId ?? "暂无设备ID")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Color(red: 0.09, green: 0.16, blue: 0.23))
                                    Text(DashboardView.listTimeFormatter.string(from: record.scannedAt))
                                    Text(record.city)
                                    Text(record.contactName)
                                    Spacer(minLength: 0)
                                }
                                .font(.system(size: 13))
                                .foregroundStyle(Color(red: 0.33, green: 0.39, blue: 0.46))

                                HStack(spacing: 10) {
                                    GeometryReader { proxy in
                                        recordScanImageStrip(record, size: proxy.size)
                                    }
                                    .frame(height: 38)
                                    .frame(maxWidth: .infinity)
                                    Text(satisfactionText(for: record))
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(satisfactionColor(for: record))
                                        .clipShape(Capsule())
                                }

                                HStack(spacing: 12) {
                                    Text(lengthDisplayText(for: record.hairLength))
                                    Text(segmentDisplayText(for: record))
                                    Text("目标色：\(record.hairColor)")
                                    Spacer(minLength: 0)
                                }
                                .font(.system(size: 13))
                                .foregroundStyle(Color(red: 0.33, green: 0.39, blue: 0.46))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 11)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    if currentRecords.isEmpty {
                        plainCard {
                            Text("暂无记录")
                                .font(.system(size: 14))
                                .foregroundStyle(Color(red: 0.42, green: 0.48, blue: 0.54))
                        }
                    }
                }
            }
            .padding(10)

            if !currentRecords.isEmpty {
                RefreshFooter(refreshing: $isLoadingMoreRecords) {
                    loadMoreRecordsFromFooter()
                } label: {
                    refreshFooterLabel(noMore: displayedRecords.count >= currentRecords.count)
                }
                .noMore(displayedRecords.count >= currentRecords.count)
                .preload(offset: 24)
            }
        }
        .enableRefresh()
        .clipped()
    }

    private func refreshHeaderLabel(progress: CGFloat) -> some View {
        HStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(0.72)
            Text(isRefreshingRecords ? "加载中..." : (progress > 1 ? "释放刷新" : "下拉刷新"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(red: 0.33, green: 0.39, blue: 0.46))
        }
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .background(Color(red: 0.95, green: 0.97, blue: 0.98))
    }

    private func refreshFooterLabel(noMore: Bool) -> some View {
        HStack {
            Spacer()
            Text(noMore ? "没有更多了" : (isLoadingMoreRecords ? "加载中..." : "上拉加载更多"))
                .font(.system(size: 12))
                .foregroundStyle(noMore ? Color(red: 0.58, green: 0.63, blue: 0.68) : Color(red: 0.42, green: 0.48, blue: 0.54))
            Spacer()
        }
        .padding(.vertical, 6)
    }

    private var resultStrip: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.82, green: 0.77, blue: 0.66),
                        Color(red: 0.79, green: 0.72, blue: 0.59)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color(red: 0.62, green: 0.59, blue: 0.53), lineWidth: 1)
            }
    }

    private func recordScanImageStrip(_ record: ScanRecord, size: CGSize) -> some View {
        ZStack {
            resultStrip

            if let imageURL = record.hairScanImageURL {
                optimizedKFImage(url: imageURL, size: size)
                    .placeholder {
                        Color.clear
                    }
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay {
            RoundedRectangle(cornerRadius: 3)
                .stroke(Color(red: 0.62, green: 0.59, blue: 0.53), lineWidth: 1)
        }
    }

    private func optimizedKFImage(url: URL, size: CGSize) -> KFImage {
        let targetSize = CGSize(
            width: max(1, ceil(size.width * 1.25)),
            height: max(1, ceil(size.height * 1.25))
        )
        let processor = DownsamplingImageProcessor(size: targetSize)

        return KFImage.url(url, cacheKey: SignedImageCacheKey.make(for: url))
            .setProcessor(processor)
            .scaleFactor(UIScreen.main.scale)
            .cacheOriginalImage()
            .backgroundDecode()
            .retry(maxCount: 2, interval: .seconds(1))
            .fade(duration: 0.15)
    }

    private var detailContent: some View {
        GeometryReader { geo in
            if let record = selectedRecord {
                let cardHeight = max(236 + detailCardInnerInset * 2, geo.size.height - detailContentInset * 2)
                let innerHeight = cardHeight - detailCardInnerInset * 2

                plainCard {
                    HStack(spacing: 6) {
                        detailMainPhoto(record: record, width: detailPhotoWidth, height: innerHeight)
                            .frame(width: detailPhotoWidth, height: innerHeight)
                            .clipped()

                        ScrollView(showsIndicators: true) {
                            VStack(spacing: 0) {
                                let items = detailFormulaItems(for: record)
                                if items.isEmpty {
                                    detailFormulaLoadingPlaceholder
                                        .frame(height: innerHeight)
                                } else {
                                    let rowHeight = innerHeight / CGFloat(items.count)
                                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                        detailItemRow(item: item, rowHeight: rowHeight)
                                            .frame(height: rowHeight, alignment: .top)

                                        if index < items.count - 1 {
                                            Divider()
                                                .overlay(Color(red: 0.93, green: 0.95, blue: 0.97))
                                        }
                                    }
                                }
                            }
                        }
                        .frame(height: innerHeight)
                        .frame(maxWidth: .infinity, alignment: .top)
                    }
                }
                .frame(height: cardHeight)
                .padding(detailContentInset)
            }
        }
    }

    private var detailFormulaLoadingPlaceholder: some View {
        VStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(.circular)
            Text(isLoadingSelectedRecordDetail ? "加载中..." : "暂无发段数据")
                .font(.system(size: 13))
                .foregroundStyle(Color(red: 0.42, green: 0.48, blue: 0.54))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func detailMainPhoto(record: ScanRecord, width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.79, green: 0.72, blue: 0.62),
                            Color(red: 0.57, green: 0.44, blue: 0.36),
                            Color(red: 0.29, green: 0.24, blue: 0.24)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(red: 0.82, green: 0.85, blue: 0.89), lineWidth: 1)
                }

            if let imageURL = record.hairColorImageURL {
                DetailMainPhotoImage(url: imageURL)
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            LinearGradient(
                colors: [
                    .clear,
                    Color.black.opacity(0.54)
                ],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(record.hairColor)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text(record.baseLevelText ?? "暂无底色范围")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.92))
                Text("差异要求1度以内")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.92))
            }
            .padding(10)
        }
        .frame(width: width, height: height)
        .clipped()
    }

    private func detailItemRow(item: DetailFormulaItem, rowHeight: CGFloat) -> some View {
        let swatchImageHeight = max(88, rowHeight - 26)

        return HStack(alignment: .top, spacing: 6) {
            swatchWithLab(label: item.lab1, alt: item.useAltSwatch, assets: item.previewAssets, displayIndex: 0, imageHeight: swatchImageHeight)
            swatchWithLab(label: item.lab2, alt: item.useAltSwatch, assets: item.previewAssets, displayIndex: 1, imageHeight: swatchImageHeight)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.degree)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.27))
                    Spacer(minLength: 8)
                    Text(item.part)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(red: 0.47, green: 0.54, blue: 0.61))
                }
                Text(item.formula)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(red: 0.33, green: 0.4, blue: 0.47))
                Text(item.ratio)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(red: 0.33, green: 0.4, blue: 0.47))
                Text(item.referenceId)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.27))
                Text(item.delta)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.27))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 5)
    }

    private func detailFormulaItems(for record: ScanRecord) -> [DetailFormulaItem] {
        if let detailItems = record.detailItems, !detailItems.isEmpty {
            return detailItems.map { item in
                DetailFormulaItem(
                    degree: item.degree,
                    part: item.part,
                    formula: item.formula,
                    ratio: item.ratio,
                    referenceId: item.referenceId,
                    delta: item.delta,
                    lab1: item.labValues.first ?? "",
                    lab2: item.labValues.dropFirst().first ?? "",
                    useAltSwatch: item.usesAlternateSwatch,
                    previewAssets: item.previewImages
                )
            }
        }

        return []
    }

    private func swatchWithLab(label: String, alt: Bool, assets: [ScanRecordPreviewImage], displayIndex: Int, imageHeight: CGFloat) -> some View {
        VStack(spacing: 4) {
            DetailPreviewImageTile(assets: assets, displayIndex: displayIndex, alt: alt)
                .frame(height: imageHeight)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Color(red: 0.41, green: 0.49, blue: 0.56))
                .lineLimit(1)
        }
        .frame(width: 100)
    }

    private var overlay: some View {
        Color.black.opacity(0.28)
            .ignoresSafeArea()
            .onTapGesture {
                filterFocusedField = nil
            }
    }

    private func filterPopup(maxWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("筛选条件")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(red: 0.09, green: 0.16, blue: 0.23))
                Spacer()
                popupButton("关闭") {
                    filterFocusedField = nil
                    showFilterPopup = false
                }
            }

            HStack(spacing: 8) {
                Toggle("按时间筛选", isOn: $usesRecordDateFilter)
                    .toggleStyle(.switch)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(red: 0.09, green: 0.16, blue: 0.23))
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                recordDateField(text: DashboardView.filterFieldDateFormatter.string(from: recordStart), field: .start)
                recordDateField(text: DashboardView.filterFieldDateFormatter.string(from: recordEnd), field: .end)
            }

            HStack(spacing: 8) {
                TextField(
                    "",
                    text: $scanViewModel.filter.store,
                    prompt: Text("门店名称").foregroundStyle(Color(red: 0.62, green: 0.67, blue: 0.72))
                )
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color(red: 0.09, green: 0.16, blue: 0.23))
                    .focused($filterFocusedField, equals: .store)
                    .submitLabel(.next)
                    .onSubmit { filterFocusedField = .city }
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(red: 0.89, green: 0.91, blue: 0.94), lineWidth: 1)
                    }

                TextField(
                    "",
                    text: $scanViewModel.filter.city,
                    prompt: Text("城市").foregroundStyle(Color(red: 0.62, green: 0.67, blue: 0.72))
                )
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color(red: 0.09, green: 0.16, blue: 0.23))
                    .focused($filterFocusedField, equals: .city)
                    .submitLabel(.next)
                    .onSubmit { filterFocusedField = .contact }
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(red: 0.89, green: 0.91, blue: 0.94), lineWidth: 1)
                    }
            }

            TextField(
                "",
                text: $scanViewModel.filter.contact,
                prompt: Text("联系人").foregroundStyle(Color(red: 0.62, green: 0.67, blue: 0.72))
            )
                .textFieldStyle(.plain)
                .foregroundStyle(Color(red: 0.09, green: 0.16, blue: 0.23))
                .focused($filterFocusedField, equals: .contact)
                .submitLabel(.done)
                .onSubmit { filterFocusedField = nil }
                .padding(.horizontal, 10)
                .frame(height: 34)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(red: 0.89, green: 0.91, blue: 0.94), lineWidth: 1)
                }

            HStack(spacing: 8) {
                Spacer()
                popupButton("重置") {
                    filterFocusedField = nil
                    scanViewModel.filter = .init()
                    usesRecordDateFilter = false
                    recordStart = Date().addingTimeInterval(-24 * 3600)
                    recordEnd = Date()
                    Task { await reloadRecords(resetPaging: true) }
                }

                popupButton("应用", primary: true) {
                    filterFocusedField = nil
                    showFilterPopup = false
                    syncRecordDateFilter()
                    Task { await reloadRecords(resetPaging: true) }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: maxWidth)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(.white)
                .onTapGesture {
                    filterFocusedField = nil
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(red: 0.89, green: 0.91, blue: 0.94), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.2), radius: 16, y: 4)
        .environment(\.colorScheme, .light)
    }

    private func filterDateField(text: String, selection: Binding<Date>) -> some View {
        ZStack(alignment: .leading) {
            DatePicker("", selection: selection, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .datePickerStyle(.compact)
                .environment(\.locale, Locale(identifier: "zh_CN"))
                .environment(\.colorScheme, .light)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .contentShape(Rectangle())

            Rectangle()
                .fill(.white)
                .allowsHitTesting(false)

            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(Color(red: 0.09, green: 0.16, blue: 0.23))
                .lineLimit(1)
                .allowsHitTesting(false)
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(red: 0.89, green: 0.91, blue: 0.94), lineWidth: 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func recordDateField(text: String, field: RecordDateField) -> some View {
        if usesRecordDateFilter {
            filterDateField(text: text, selection: recordDateBinding(for: field))
        } else {
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(Color(red: 0.45, green: 0.51, blue: 0.57))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .frame(height: 34)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 0.96, green: 0.97, blue: 0.98))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(red: 0.89, green: 0.91, blue: 0.94), lineWidth: 1)
                }
                .onTapGesture {
                    usesRecordDateFilter = true
                }
        }
    }

    private enum RecordDateField {
        case start
        case end
    }

    private func recordDateBinding(for field: RecordDateField) -> Binding<Date> {
        Binding(
            get: {
                switch field {
                case .start:
                    return recordStart
                case .end:
                    return recordEnd
                }
            },
            set: { newValue in
                usesRecordDateFilter = true
                switch field {
                case .start:
                    recordStart = newValue
                case .end:
                    recordEnd = newValue
                }
            }
        )
    }

    private func popupButton(_ title: String, primary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .frame(minWidth: 56, minHeight: 30)
                .foregroundStyle(primary ? .white : Color(red: 0.09, green: 0.16, blue: 0.23))
                .background(primary ? Color(red: 0.06, green: 0.44, blue: 0.71) : .white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(primary ? Color(red: 0.06, green: 0.44, blue: 0.71) : Color(red: 0.89, green: 0.91, blue: 0.94), lineWidth: 1)
                }
        }
    }

    private var loadingCard: some View {
        card {
            HStack {
                Spacer()
                ProgressView("加载中...")
                    .font(.system(size: 14))
                Spacer()
            }
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(red: 0.89, green: 0.91, blue: 0.94), lineWidth: 1)
            }
    }

    private func plainCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func kpiGridCard(items: [(String, String)]) -> some View {
        card {
            if items.isEmpty {
                Text("暂无数据")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(red: 0.42, green: 0.48, blue: 0.54))
            } else {
                Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                    let rowCount = (items.count + 1) / 2
                    ForEach(0..<rowCount, id: \.self) { rowIndex in
                        GridRow {
                            let left = rowIndex * 2
                            kpiCell(items[left])
                            if left + 1 < items.count {
                                kpiCell(items[left + 1])
                            } else {
                                Color.clear
                            }
                        }
                    }
                }
            }
        }
    }

    private func kpiCell(_ row: (String, String)) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(row.0)
                .font(.system(size: 13))
                .foregroundStyle(Color(red: 0.42, green: 0.48, blue: 0.54))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(row.1)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(Color(red: 0.05, green: 0.36, blue: 0.59))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
        .background(Color(red: 0.98, green: 0.99, blue: 1.0))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(red: 0.89, green: 0.91, blue: 0.94), lineWidth: 1)
        }
    }

    private func segmented(options: [String], selectedIndex: Int, onTap: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                Button {
                    onTap(index)
                } label: {
                    Text(option)
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 26)
                        .foregroundStyle(selectedIndex == index ? Color(red: 0.06, green: 0.44, blue: 0.71) : Color(red: 0.35, green: 0.44, blue: 0.52))
                        .background(selectedIndex == index ? .white : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(3)
        .background(Color(red: 0.95, green: 0.97, blue: 0.98))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(red: 0.89, green: 0.91, blue: 0.94), lineWidth: 1)
        }
    }

    private func onTapBack() {
        switch page {
        case .home:
            break
        case .records:
            page = .home
        case .detail:
            page = .records
        }
    }

    private var pageTitle: String {
        switch page {
        case .home: return "统计"
        case .records: return "扫描记录"
        case .detail:
            if let selectedRecord {
                return detailTitle(for: selectedRecord)
            }
            return "扫描详情"
        }
    }

    private func detailTitle(for record: ScanRecord) -> String {
        record.deviceId ?? "扫描详情"
    }

    private func openDetail(_ record: ScanRecord) {
        selectedRecord = record
        page = .detail
        isLoadingSelectedRecordDetail = true

        Task {
            let detail = await scanViewModel.loadDetail(for: record)
            selectedRecord = detail
            isLoadingSelectedRecordDetail = false
        }
    }

    private var statsPaneIndex: Int {
        switch statsPane {
        case .all: return 0
        case .quick: return 1
        case .custom: return 2
        }
    }

    private var currentRecords: [ScanRecord] {
        if case let .loaded(records) = scanViewModel.state {
            return records
        }
        return []
    }

    private var isShowingRequestHUD: Bool {
        (dashboardViewModel.isRequesting && !dashboardViewModel.hasLoadedStats)
            || (scanViewModel.isRequesting && (page != .records || !scanViewModel.hasLoadedRecords))
    }

    private var displayedRecords: [ScanRecord] {
        Array(currentRecords.prefix(visibleRecordCount))
    }

    @MainActor
    private func reloadStatsForCurrentSelection() async {
        switch statsPane {
        case .all:
            await dashboardViewModel.load(.cumulative)
        case .quick:
            await dashboardViewModel.load(.preset(quickRange.statsPreset))
        case .custom:
            await dashboardViewModel.load(.custom(start: customStart, end: customEnd))
        }
    }

    @MainActor
    private func loadRecordsIfNeeded() async {
        if case .idle = scanViewModel.state {
            await reloadRecords(resetPaging: true)
        }
    }

    @MainActor
    private func reloadRecords(resetPaging: Bool) async {
        let previousVisibleCount = visibleRecordCount
        if let recordReloadTask {
            await recordReloadTask.value
            updateRecordPaging(reset: resetPaging, previousVisibleCount: previousVisibleCount)
            return
        }

        syncRecordDateFilter()
        let task = Task {
            await scanViewModel.load()
        }
        recordReloadTask = task
        await task.value
        recordReloadTask = nil
        updateRecordPaging(reset: resetPaging, previousVisibleCount: previousVisibleCount)
        prefetchVisibleRecordImages()
    }

    private func syncRecordDateFilter() {
        if usesRecordDateFilter {
            scanViewModel.filter.startTime = min(recordStart, recordEnd)
            scanViewModel.filter.endTime = max(recordStart, recordEnd)
        } else {
            scanViewModel.filter.startTime = nil
            scanViewModel.filter.endTime = nil
        }
    }

    private func updateRecordPaging(reset: Bool, previousVisibleCount: Int) {
        if currentRecords.isEmpty {
            visibleRecordCount = 0
        } else if reset {
            visibleRecordCount = max(1, min(recordPageSize, currentRecords.count))
        } else {
            visibleRecordCount = max(1, min(max(recordPageSize, previousVisibleCount), currentRecords.count))
        }
        isLoadingMoreRecords = false
    }

    private func refreshRecordsFromHeader() {
        guard !scanViewModel.isRequesting else {
            isRefreshingRecords = false
            return
        }

        Task {
            await reloadRecords(resetPaging: false)
            isRefreshingRecords = false
        }
    }

    private func loadMoreRecordsFromFooter() {
        guard displayedRecords.count < currentRecords.count else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            visibleRecordCount = min(visibleRecordCount + recordPageSize, currentRecords.count)
            isLoadingMoreRecords = false
            prefetchVisibleRecordImages()
        }
    }

    private func prefetchVisibleRecordImages() {
        let resources: [any Resource] = displayedRecords.compactMap { record -> KF.ImageResource? in
            guard let url = record.hairScanImageURL else { return nil }
            return KF.ImageResource(downloadURL: url, cacheKey: SignedImageCacheKey.make(for: url))
        }
        guard !resources.isEmpty else { return }

        ImagePrefetcher(
            resources: resources,
            options: [.cacheOriginalImage, .backgroundDecode]
        ).start()
    }

    private func lengthDisplayText(for value: String) -> String {
        if value.hasSuffix("cm") {
            return value
        }

        switch value {
        case "中长":
            return "25cm"
        case "短发":
            return "15cm"
        case "长发":
            return "30cm"
        case "中短":
            return "20cm"
        default:
            return value
        }
    }

    private func satisfactionText(for record: ScanRecord) -> String {
        guard record.satisfactionScore != nil else {
            return "未评价"
        }
        return record.satisfied ? "满意" : "不满意"
    }

    private func satisfactionColor(for record: ScanRecord) -> Color {
        guard record.satisfactionScore != nil else {
            return Color(red: 0.56, green: 0.61, blue: 0.67)
        }
        return record.satisfied ? Color(red: 0.16, green: 0.68, blue: 0.36) : Color(red: 0.88, green: 0.24, blue: 0.21)
    }

    private func segmentDisplayText(for record: ScanRecord) -> String {
        if let segmentCount = record.segmentCount {
            return "分\(segmentCount)段"
        }
        return record.hairLength.contains("长") ? "分1段" : "分2段"
    }
}
