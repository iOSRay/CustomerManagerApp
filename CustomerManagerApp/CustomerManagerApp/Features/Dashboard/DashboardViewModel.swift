import Foundation
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {
    enum State {
        case idle
        case loading
        case loaded(DashboardStats)
        case failed(String)
    }

    private let statsService: StatsServiceProtocol
    @Published private(set) var state: State = .idle
    @Published private(set) var noticeMessage: String?
    @Published private(set) var isRequesting = false
    private(set) var currentQuery: UsageStatsQuery = .cumulative
    private var requestCount = 0
    private var requestSequence = 0

    init(statsService: StatsServiceProtocol) {
        self.statsService = statsService
    }

    func load(_ query: UsageStatsQuery = .cumulative) async {
        requestSequence += 1
        let sequence = requestSequence

        currentQuery = query
        state = .loading
        noticeMessage = nil
        beginRequest()
        defer { endRequest() }

        do {
            let stats = try await statsService.fetchUsageStats(query)
            guard sequence == requestSequence else { return }
            state = .loaded(stats)
        } catch {
            guard sequence == requestSequence else { return }
            // Keep page usable when network is unavailable.
            state = .loaded(PreviewMocks.stats)
            noticeMessage = "网络异常，已展示离线数据"
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
