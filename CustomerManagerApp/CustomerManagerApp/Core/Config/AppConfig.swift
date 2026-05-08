import Foundation

enum AppConstants {
    static let apiBaseURL = URL(string: "https://api.test.davincidye.com")!

    enum Admin {
        static let username = "admin"
        static let password = "DavinciTestAdmin2026!"
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
