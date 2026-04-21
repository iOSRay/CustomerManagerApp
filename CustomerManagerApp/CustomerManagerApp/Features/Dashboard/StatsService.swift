import Foundation

protocol StatsServiceProtocol {
    func fetchAllTimeStats() async throws -> DashboardStats
}

struct StatsEndpoint: APIEndpoint {
    let path: String = "/v1/stats/all-time"
    let method: HTTPMethod = .get
}

final class StatsService: StatsServiceProtocol {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func fetchAllTimeStats() async throws -> DashboardStats {
        try await apiClient.request(StatsEndpoint(), as: DashboardStats.self)
    }
}
