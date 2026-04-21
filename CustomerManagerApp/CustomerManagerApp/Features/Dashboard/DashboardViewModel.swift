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

    init(statsService: StatsServiceProtocol) {
        self.statsService = statsService
    }

    func load() async {
        state = .loading
        noticeMessage = nil
        do {
            let stats = try await statsService.fetchAllTimeStats()
            state = .loaded(stats)
        } catch {
            // Keep page usable when network is unavailable.
            state = .loaded(PreviewMocks.stats)
            noticeMessage = "网络异常，已展示离线数据"
        }
    }

}
