import SwiftUI

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

private enum QuickRange: Int, CaseIterable {
    case h24 = 24
    case h48 = 48
    case h72 = 72
    case week = 168

    var title: String {
        switch self {
        case .h24: return "24h"
        case .h48: return "48h"
        case .h72: return "72h"
        case .week: return "1周"
        }
    }
}

private enum FilterField: Hashable {
    case store
    case city
    case contact
}

private struct RangeMetrics {
    let totalUses: Int
    let activeDevices: Int
    let soldDevices: Int

    var usageRateText: String {
        guard soldDevices > 0 else { return "0%" }
        let value = Double(activeDevices) / Double(soldDevices) * 100
        return "\(Int(value.rounded()))%"
    }
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
    @State private var visibleRecordCount = 12
    @State private var isLoadingMoreRecords = false
    @FocusState private var filterFocusedField: FilterField?

    private let recordPageSize = 12

    init(dashboardViewModel: DashboardViewModel, scanViewModel: ScanRecordListViewModel) {
        _dashboardViewModel = StateObject(wrappedValue: dashboardViewModel)
        _scanViewModel = StateObject(wrappedValue: scanViewModel)
    }

    var body: some View {
        GeometryReader { geo in
            let sideInset: CGFloat = 0

            ZStack {
                Color(red: 0.95, green: 0.97, blue: 0.98).ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar
                    content
                }
                .padding(.horizontal, sideInset)
                .background(Color(red: 0.95, green: 0.97, blue: 0.98))

                if showFilterPopup, page == .records {
                    overlay
                    filterPopup(maxWidth: min(520, geo.size.width - sideInset * 2 - 20))
                }
            }
            .task {
                await dashboardViewModel.load()
                await reloadRecords()
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
        .background(.white)
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
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch page {
        case .home:
            topActionButton(title: "记录") {
                page = .records
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
                .frame(minWidth: 56, minHeight: 30)
                .foregroundStyle(Color(red: 0.09, green: 0.16, blue: 0.23))
                .background(.white)
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(red: 0.89, green: 0.91, blue: 0.94), lineWidth: 1)
                }
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
                        statsPane = [StatsPane.all, .quick, .custom][index]
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
        Group {
            if case let .loaded(stats) = dashboardViewModel.state {
                kpiGridCard(items: [
                    ("卖出设备总数", "\(stats.soldDevices)"),
                    ("总使用次数", "\(stats.totalUsages)"),
                    ("至少使用过1次设备数", "\(stats.activeDevices)"),
                    ("使用率", "\(Int((stats.usageRate * 100).rounded()))%")
                ])
            } else if case .loading = dashboardViewModel.state {
                loadingCard
            } else {
                kpiGridCard(items: [])
            }
        }
    }

    private var statsCardQuick: some View {
        VStack(alignment: .leading, spacing: 8) {
            segmented(
                options: QuickRange.allCases.map(\.title),
                selectedIndex: QuickRange.allCases.firstIndex(of: quickRange) ?? 0,
                onTap: { index in
                    quickRange = QuickRange.allCases[index]
                }
            )

            let metrics = rangeMetrics(hours: quickRange.rawValue)
            kpiGridCard(items: [
                ("总使用次数", "\(metrics.totalUses)"),
                ("使用设备数", "\(metrics.activeDevices)"),
                ("使用率", metrics.usageRateText)
            ])
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

                popupButton("计算", primary: true) {}
                    .frame(minWidth: 72)
            }

            let metrics = customRangeMetrics
            kpiGridCard(items: [
                ("总使用次数", "\(metrics.totalUses)"),
                ("使用设备数", "\(metrics.activeDevices)"),
                ("使用率", metrics.usageRateText)
            ])
        }
    }

    private var recordsContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 8) {
                if case .loading = scanViewModel.state {
                    loadingCard
                } else {
                    ForEach(displayedRecords) { record in
                        Button {
                            selectedRecord = record
                            page = .detail
                        } label: {
                            VStack(alignment: .leading, spacing: 7) {
                                HStack(spacing: 10) {
                                    Text(record.deviceId ?? "hair_item_\(record.id.uuidString.prefix(4))")
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
                                    resultStrip
                                        .frame(height: 38)
                                        .frame(maxWidth: .infinity)
                                    Text(record.satisfied ? "满意" : "不满意")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(record.satisfied ? Color(red: 0.16, green: 0.68, blue: 0.36) : Color(red: 0.88, green: 0.24, blue: 0.21))
                                        .clipShape(Capsule())
                                }

                                HStack(spacing: 12) {
                                    Text(lengthDisplayText(for: record.hairLength))
                                    Text(segmentDisplayText(for: record.hairLength))
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
                        .onAppear {
                            loadMoreIfNeeded(currentRecord: record)
                        }
                    }

                    if currentRecords.isEmpty {
                        plainCard {
                            Text("暂无记录")
                                .font(.system(size: 14))
                                .foregroundStyle(Color(red: 0.42, green: 0.48, blue: 0.54))
                        }
                    } else if displayedRecords.count < currentRecords.count {
                        HStack {
                            Spacer()
                            Text(isLoadingMoreRecords ? "加载中..." : "上拉加载更多")
                                .font(.system(size: 12))
                                .foregroundStyle(Color(red: 0.42, green: 0.48, blue: 0.54))
                            Spacer()
                        }
                        .padding(.vertical, 6)
                    } else {
                        HStack {
                            Spacer()
                            Text("没有更多了")
                                .font(.system(size: 12))
                                .foregroundStyle(Color(red: 0.58, green: 0.63, blue: 0.68))
                            Spacer()
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .padding(10)
        }
        .refreshable {
            await reloadRecords()
        }
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

    private var detailContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let record = selectedRecord {
                plainCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(record.deviceId ?? "hair_item_\(record.id.uuidString.prefix(4))")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(red: 0.15, green: 0.22, blue: 0.3))

                        HStack(spacing: 6) {
                            detailMainPhoto(color: record.hairColor)
                                .frame(width: 160, height: 236)

                            ScrollView(showsIndicators: true) {
                                VStack(spacing: 0) {
                                    let items = detailFormulaItems(for: record)
                                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                        detailItemRow(item: item)

                                        if index < items.count - 1 {
                                            Divider()
                                                .overlay(Color(red: 0.93, green: 0.95, blue: 0.97))
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: 236, alignment: .top)
                        }
                    }
                }
            }
        }
        .padding(10)
    }

    private func detailMainPhoto(color: String) -> some View {
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
            VStack(alignment: .leading, spacing: 4) {
                Text(color)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text("7.5–9.0度")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.92))
                Text("差异要求1度以内")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.92))
            }
            .padding(10)
        }
    }

    private func detailItemRow(item: DetailFormulaItem) -> some View {
        HStack(alignment: .top, spacing: 6) {
            swatchWithLab(label: item.lab1, alt: item.useAltSwatch)
            swatchWithLab(label: item.lab2, alt: item.useAltSwatch)

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
        [
            DetailFormulaItem(
                degree: record.satisfied ? "8.5度" : "8.3度",
                part: "根部 8.0cm",
                formula: "配方：\(record.formula)",
                ratio: "比例：2 : 2 : 1 : 10 : 15",
                referenceId: "参考发条id: A1794-1",
                delta: record.satisfied ? "Delta: 0.32" : "Delta: 0.58",
                lab1: record.satisfied ? "Lab: 62.1, 7.8, 18.4" : "Lab: 61.3, 8.4, 19.1",
                lab2: record.satisfied ? "Lab: 63.4, 8.1, 17.9" : "Lab: 62.0, 8.8, 18.6",
                useAltSwatch: false
            ),
            DetailFormulaItem(
                degree: record.satisfied ? "8.0度" : "7.8度",
                part: "尾部 6.7cm",
                formula: "配方：6/77 + 8/65 + 4/0 + 00 + 3%",
                ratio: "比例：3 : 3 : 2 : 24 : 32",
                referenceId: "参考发条id: ZA887-3",
                delta: record.satisfied ? "Delta: 0.47" : "Delta: 0.73",
                lab1: record.satisfied ? "Lab: 59.6, 9.2, 16.5" : "Lab: 58.2, 9.8, 17.3",
                lab2: record.satisfied ? "Lab: 60.1, 8.9, 15.8" : "Lab: 58.8, 9.5, 16.7",
                useAltSwatch: true
            )
        ]
    }

    private func swatchWithLab(label: String, alt: Bool) -> some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        colors: alt
                            ? [Color(red: 0.85, green: 0.70, blue: 0.50), Color(red: 0.80, green: 0.63, blue: 0.43)]
                            : [Color(red: 0.88, green: 0.77, blue: 0.58), Color(red: 0.83, green: 0.69, blue: 0.46)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color(red: 0.80, green: 0.72, blue: 0.61), lineWidth: 1)
                }
                .frame(height: 88)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Color(red: 0.41, green: 0.49, blue: 0.56))
                .lineLimit(1)
        }
        .frame(width: 92)
    }

    private var overlay: some View {
        Color.black.opacity(0.28)
            .ignoresSafeArea()
            .onTapGesture {
                filterFocusedField = nil
                showFilterPopup = false
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
                filterDateField(text: DashboardView.filterFieldDateFormatter.string(from: customStart), selection: $customStart)
                filterDateField(text: DashboardView.filterFieldDateFormatter.string(from: customEnd), selection: $customEnd)
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
                    Task { await reloadRecords() }
                }

                popupButton("应用", primary: true) {
                    filterFocusedField = nil
                    showFilterPopup = false
                    Task { await reloadRecords() }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: maxWidth)
        .background(.white)
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
        case .detail: return "扫描详情"
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

    private var displayedRecords: [ScanRecord] {
        Array(currentRecords.prefix(visibleRecordCount))
    }

    private var soldDevicesValue: Int {
        if case let .loaded(stats) = dashboardViewModel.state {
            return stats.soldDevices
        }
        return PreviewMocks.stats.soldDevices
    }

    private func rangeMetrics(hours: Int) -> RangeMetrics {
        let now = Date()
        let start = now.addingTimeInterval(TimeInterval(-hours * 3600))
        let inRange = currentRecords.filter { $0.scannedAt >= start && $0.scannedAt <= now }
        let active = Set(inRange.map { $0.deviceId ?? "\($0.storeName)-\($0.contactName)" }).count
        return RangeMetrics(totalUses: inRange.count, activeDevices: active, soldDevices: soldDevicesValue)
    }

    private var customRangeMetrics: RangeMetrics {
        let start = min(customStart, customEnd)
        let end = max(customStart, customEnd)
        let inRange = currentRecords.filter { $0.scannedAt >= start && $0.scannedAt <= end }
        let active = Set(inRange.map { $0.deviceId ?? "\($0.storeName)-\($0.contactName)" }).count
        return RangeMetrics(totalUses: inRange.count, activeDevices: active, soldDevices: soldDevicesValue)
    }

    @MainActor
    private func reloadRecords() async {
        await scanViewModel.load()
        resetRecordPaging()
    }

    private func resetRecordPaging() {
        visibleRecordCount = min(recordPageSize, currentRecords.count)
        isLoadingMoreRecords = false
    }

    private func loadMoreIfNeeded(currentRecord: ScanRecord) {
        guard !isLoadingMoreRecords else { return }
        guard displayedRecords.count < currentRecords.count else { return }
        guard currentRecord.id == displayedRecords.last?.id else { return }

        isLoadingMoreRecords = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            visibleRecordCount = min(visibleRecordCount + recordPageSize, currentRecords.count)
            isLoadingMoreRecords = false
        }
    }

    private func lengthDisplayText(for value: String) -> String {
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

    private func segmentDisplayText(for value: String) -> String {
        value.contains("长") ? "分1段" : "分2段"
    }
}
