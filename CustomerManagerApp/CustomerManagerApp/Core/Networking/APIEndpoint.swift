import Foundation

protocol APIEndpoint {
    var path: String { get }
    var method: HTTPMethod { get }
    var queryItems: [URLQueryItem] { get }
    var body: (any Encodable)? { get }
    var headers: [String: String] { get }
}

extension APIEndpoint {
    var queryItems: [URLQueryItem] { [] }
    var body: (any Encodable)? { nil }
    var headers: [String: String] { [:] }
}
