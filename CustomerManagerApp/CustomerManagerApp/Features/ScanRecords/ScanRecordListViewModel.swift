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
        var store: String = ""
        var city: String = ""
        var contact: String = ""
    }

    private let scanRecordService: ScanRecordServiceProtocol
    @Published private(set) var state: State = .idle
    @Published var filter = Filter()
    @Published private(set) var noticeMessage: String?

    init(scanRecordService: ScanRecordServiceProtocol) {
        self.scanRecordService = scanRecordService
    }

    func load() async {
        state = .loading
        noticeMessage = nil
        do {
            let records = try await scanRecordService.fetchRecords(
                store: filter.store,
                city: filter.city,
                contact: filter.contact
            )
            state = .loaded(records)
        } catch {
            // Keep list available with offline fallback data.
            state = .loaded(PreviewMocks.records)
            noticeMessage = "网络异常，已展示离线数据"
        }
    }
}
