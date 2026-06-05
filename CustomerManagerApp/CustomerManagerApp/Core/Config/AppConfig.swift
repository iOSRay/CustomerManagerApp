import Foundation

enum AppConstants {
    enum Environment {
        case production
        case test
    }

    static let currentEnvironment: Environment = .production

    static let apiBaseURL = current.apiBaseURL

    enum Admin {
        static let username = current.adminUsername
        static let password = current.adminPassword
    }

    private static var current: EnvironmentConfig {
        switch currentEnvironment {
        case .production:
            return .production
        case .test:
            return .test
        }
    }

    private struct EnvironmentConfig {
        let apiBaseURL: URL
        let adminUsername: String
        let adminPassword: String

        static let production = EnvironmentConfig(
            apiBaseURL: URL(string: "https://api.davincidye.com")!,
            adminUsername: "admin",
            adminPassword: "j6#Fp2K8&vLq%"
        )

        static let test = EnvironmentConfig(
            apiBaseURL: URL(string: "https://api.test.davincidye.com")!,
            adminUsername: "admin",
            adminPassword: "DavinciTestAdmin2026!"
        )
    }
}

struct AppConfig {
    struct AdminCredentials {
        let username: String
        let password: String
    }

    let baseURL: URL
    let adminCredentials: AdminCredentials?

    static let `default` = AppConfig(
        baseURL: AppConstants.apiBaseURL,
        adminCredentials: AdminCredentials(
            username: AppConstants.Admin.username,
            password: AppConstants.Admin.password
        )
    )
}
