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

    var hasLoadedStats: Bool {
        loadedStats != nil
    }

    init(statsService: StatsServiceProtocol) {
        self.statsService = statsService
    }

    func load(_ query: UsageStatsQuery = .cumulative) async {
        requestSequence += 1
        let sequence = requestSequence
        let previousStats = loadedStats

        currentQuery = query
        if previousStats == nil {
            state = .loading
        }
        noticeMessage = nil
        beginRequest()
        defer { endRequest() }

        do {
            let stats = try await statsService.fetchUsageStats(query)
            guard sequence == requestSequence else { return }
            state = .loaded(stats)
        } catch {
            guard sequence == requestSequence else { return }
            if let previousStats {
                state = .loaded(previousStats)
                noticeMessage = "网络异常，已保留上次数据"
            } else {
                state = .failed("统计数据加载失败")
                noticeMessage = "统计数据加载失败"
            }
        }
    }

    private var loadedStats: DashboardStats? {
        if case let .loaded(stats) = state {
            return stats
        }
        return nil
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
