import Foundation
import Combine

@MainActor
final class ScanRecordListViewModel: ObservableObject {
    enum State {
        case idle
        case loading
        case loaded([ScanRecord])
        case failed(String)
    }

    struct Filter {
        static let pageSize = 20

        var startTime: Date?
        var endTime: Date?
        var store: String = ""
        var city: String = ""
        var contact: String = ""

        func query(page: Int) -> ScanRecordQuery {
            ScanRecordQuery(
                page: page,
                size: Self.pageSize,
                startTime: startTime,
                endTime: endTime,
                storeName: store,
                city: city,
                contactPerson: contact
            )
        }
    }

    private let scanRecordService: ScanRecordServiceProtocol
    @Published private(set) var state: State = .idle
    @Published var filter = Filter()
    @Published private(set) var noticeMessage: String?
    @Published private(set) var isRequesting = false
    @Published private(set) var hasMoreRecords = false
    private var isLoadingList = false
    private var requestCount = 0
    private var currentPage = 0

    var hasLoadedRecords: Bool {
        loadedRecords != nil
    }

    init(scanRecordService: ScanRecordServiceProtocol) {
        self.scanRecordService = scanRecordService
    }

    func load(reset: Bool = true) async {
        guard !isLoadingList else { return }
        guard reset || hasMoreRecords else { return }
        isLoadingList = true
        beginRequest()
        defer {
            isLoadingList = false
            endRequest()
        }

        let previousRecords: [ScanRecord]
        if case let .loaded(records) = state {
            previousRecords = records
        } else {
            previousRecords = []
            state = .loading
        }
        noticeMessage = nil
        do {
            let nextPage = reset ? 1 : currentPage + 1
            let page = try await scanRecordService.fetchRecords(filter: filter.query(page: nextPage))
            let records = reset ? page.records : previousRecords + page.records
            currentPage = page.page
            hasMoreRecords = hasMore(total: page.total, loadedCount: records.count, pageCount: page.records.count, pageSize: page.size)
            state = .loaded(records)
        } catch {
            if previousRecords.isEmpty {
                state = .failed("扫描记录加载失败")
            } else {
                state = .loaded(previousRecords)
            }
            noticeMessage = "扫描记录加载失败"
        }
    }

    private func hasMore(total: Int?, loadedCount: Int, pageCount: Int, pageSize: Int) -> Bool {
        if let total {
            return loadedCount < total
        }
        return pageCount >= pageSize
    }

    private var loadedRecords: [ScanRecord]? {
        if case let .loaded(records) = state {
            return records
        }
        return nil
    }

    func loadDetail(for record: ScanRecord) async -> ScanRecord {
        guard let workId = record.workId else {
            return record
        }

        beginRequest()
        defer { endRequest() }

        do {
            return try await scanRecordService.fetchRecordDetail(workId: workId)
        } catch {
            noticeMessage = "详情加载失败，已展示列表数据"
            return record
        }
    }

    private func beginRequest() {
        requestCount += 1
        isRequesting = true
    }

    private func endRequest() {
        requestCount = max(0, requestCount - 1)
        isRequesting = requestCount > 0
    }
}
