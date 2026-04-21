import Foundation

struct AppConfig {
    let baseURL: URL

    static let `default` = AppConfig(
        baseURL: URL(string: "https://api.example.com")!
    )
}
