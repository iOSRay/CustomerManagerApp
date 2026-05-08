import Foundation

final class AppContainer {
    let apiClient: APIClientProtocol
    let statsService: StatsServiceProtocol
    let scanRecordService: ScanRecordServiceProtocol

    init(
        apiClient: APIClientProtocol,
        statsService: StatsServiceProtocol,
        scanRecordService: ScanRecordServiceProtocol
    ) {
        self.apiClient = apiClient
        self.statsService = statsService
        self.scanRecordService = scanRecordService
    }

    static let live: AppContainer = {
        let config = AppConfig.default
        let client = APIClient(baseURL: config.baseURL)
        let authService = AdminAuthService(apiClient: client, credentials: config.adminCredentials)
        let statsService = StatsService(apiClient: client, authService: authService)
        let scanRecordService = ScanRecordService(apiClient: client, authService: authService)
        return AppContainer(apiClient: client, statsService: statsService, scanRecordService: scanRecordService)
    }()
}
