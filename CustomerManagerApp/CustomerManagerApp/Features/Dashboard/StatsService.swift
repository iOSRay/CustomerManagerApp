import Foundation

protocol AdminAuthServiceProtocol {
    func authorizationHeader() async throws -> String
}

struct AdminLoginEndpoint: APIEndpoint {
    struct Body: Encodable {
        let username: String
        let password: String
    }

    let path: String = "/v1/admin/auth/login"
    let method: HTTPMethod = .post
    let body: (any Encodable)?

    init(username: String, password: String) {
        body = Body(username: username, password: password)
    }
}

struct AdminLoginResponse: Decodable {
    let accessToken: String
    let tokenType: String

    var authorizationHeader: String {
        "\(tokenType.capitalized) \(accessToken)"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let data = try? container.decode(ResponseData.self, forKey: .data) {
            accessToken = data.accessToken
            tokenType = data.tokenType
            return
        }

        if let token = try? container.decode(Token.self, forKey: .token) {
            accessToken = token.accessToken
            tokenType = token.tokenType
            return
        }

        if let token = try? container.decode(String.self, forKey: .token) {
            accessToken = token
            tokenType = "bearer"
            return
        }

        accessToken = try container.decode(String.self, forKey: .accessToken)
        tokenType = try container.decodeIfPresent(String.self, forKey: .tokenType) ?? "bearer"
    }

    private struct ResponseData: Decodable {
        let accessToken: String
        let tokenType: String

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            if let token = try? container.decode(Token.self, forKey: .token) {
                accessToken = token.accessToken
                tokenType = token.tokenType
                return
            }

            if let token = try? container.decode(String.self, forKey: .token) {
                accessToken = token
                tokenType = "bearer"
                return
            }

            accessToken = try container.decode(String.self, forKey: .accessToken)
            tokenType = try container.decodeIfPresent(String.self, forKey: .tokenType) ?? "bearer"
        }

        private enum CodingKeys: String, CodingKey {
            case token
            case accessToken = "access_token"
            case tokenType = "token_type"
        }
    }

    private struct Token: Decodable {
        let accessToken: String
        let tokenType: String

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            accessToken = try container.decode(String.self, forKey: .accessToken)
            tokenType = try container.decodeIfPresent(String.self, forKey: .tokenType) ?? "bearer"
        }

        private enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case tokenType = "token_type"
        }
    }

    private enum CodingKeys: String, CodingKey {
        case data
        case token
        case accessToken = "access_token"
        case tokenType = "token_type"
    }
}

final class AdminAuthService: AdminAuthServiceProtocol {
    private let apiClient: APIClientProtocol
    private let credentials: AppConfig.AdminCredentials?
    private var cachedAuthorizationHeader: String?

    init(apiClient: APIClientProtocol, credentials: AppConfig.AdminCredentials?) {
        self.apiClient = apiClient
        self.credentials = credentials
    }

    func authorizationHeader() async throws -> String {
        if let cachedAuthorizationHeader {
            return cachedAuthorizationHeader
        }

        guard let credentials else {
            throw NetworkError.http(statusCode: 401, message: "缺少管理员账号密码配置")
        }

        let response = try await apiClient.request(
            AdminLoginEndpoint(username: credentials.username, password: credentials.password),
            as: AdminLoginResponse.self
        )
        let header = response.authorizationHeader
        cachedAuthorizationHeader = header
        return header
    }
}

enum UsageStatsQuery: Equatable {
    enum Mode: String {
        case cumulative
        case preset
        case custom
    }

    enum Preset: String, CaseIterable {
        case h24 = "24h"
        case h48 = "48h"
        case h72 = "72h"
        case d7 = "7d"
    }

    case cumulative
    case preset(Preset, rangeEnd: Date? = nil)
    case custom(start: Date, end: Date)

    var mode: Mode {
        switch self {
        case .cumulative:
            return .cumulative
        case .preset:
            return .preset
        case .custom:
            return .custom
        }
    }
}

protocol StatsServiceProtocol {
    func fetchUsageStats(_ query: UsageStatsQuery) async throws -> DashboardStats
}

struct StatsEndpoint: APIEndpoint {
    let path: String = "/v1/admin/usage-stats"
    let method: HTTPMethod = .get
    let queryItems: [URLQueryItem]
    let headers: [String: String]

    init(query: UsageStatsQuery, authorization: String) {
        var items = [
            URLQueryItem(name: "mode", value: query.mode.rawValue)
        ]

        switch query {
        case .cumulative:
            break
        case let .preset(preset, rangeEnd):
            items.append(URLQueryItem(name: "preset", value: preset.rawValue))
            if let rangeEnd {
                items.append(URLQueryItem(name: "range_end", value: Self.dateFormatter.string(from: rangeEnd)))
            }
        case let .custom(start, end):
            items.append(URLQueryItem(name: "custom_start", value: Self.dateFormatter.string(from: min(start, end))))
            items.append(URLQueryItem(name: "custom_end", value: Self.dateFormatter.string(from: max(start, end))))
        }

        queryItems = items
        headers = ["Authorization": authorization]
    }

    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = .current
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

final class StatsService: StatsServiceProtocol {
    private let apiClient: APIClientProtocol
    private let authService: AdminAuthServiceProtocol

    init(apiClient: APIClientProtocol, authService: AdminAuthServiceProtocol) {
        self.apiClient = apiClient
        self.authService = authService
    }

    func fetchUsageStats(_ query: UsageStatsQuery) async throws -> DashboardStats {
        let authorization = try await authService.authorizationHeader()
        return try await apiClient.request(StatsEndpoint(query: query, authorization: authorization), as: DashboardStats.self)
    }
}
