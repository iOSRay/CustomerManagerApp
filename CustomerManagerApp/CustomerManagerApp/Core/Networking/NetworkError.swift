import Foundation

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingFailed
    case http(statusCode: Int, message: String?)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "请求地址无效"
        case .invalidResponse:
            return "服务响应格式无效"
        case .decodingFailed:
            return "数据解析失败"
        case let .http(code, message):
            return "请求失败(\(code))\(message.map { ": \($0)" } ?? "")"
        case let .transport(error):
            return "网络异常: \(error.localizedDescription)"
        }
    }
}
