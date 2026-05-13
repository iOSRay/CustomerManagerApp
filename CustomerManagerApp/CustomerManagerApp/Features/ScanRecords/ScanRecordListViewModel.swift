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
        var startTime: Date?
        var endTime: Date?
        var store: String = ""
        var city: String = ""
        var contact: String = ""

        var query: ScanRecordQuery {
            ScanRecordQuery(
                page: 1,
                size: 20,
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
    private var isLoadingList = false
    private var requestCount = 0

    var hasLoadedRecords: Bool {
        loadedRecords != nil
    }

    init(scanRecordService: ScanRecordServiceProtocol) {
        self.scanRecordService = scanRecordService
    }

    func load() async {
        guard !isLoadingList else { return }
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
            let records = try await scanRecordService.fetchRecords(filter: filter.query)
            state = .loaded(records)
        } catch {
            // Keep list available with offline fallback data.
            state = .loaded(previousRecords.isEmpty ? PreviewMocks.records : previousRecords)
            noticeMessage = "网络异常，已展示离线数据"
        }
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
