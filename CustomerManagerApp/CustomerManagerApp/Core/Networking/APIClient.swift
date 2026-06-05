import Foundation

protocol APIClientProtocol {
    func request<T: Decodable>(_ endpoint: APIEndpoint, as type: T.Type) async throws -> T
}

final class APIClient: APIClientProtocol {
    private let baseURL: URL
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let logsEnabled: Bool

    init(
        baseURL: URL,
        session: URLSession = .shared,
        encoder: JSONEncoder = .init(),
        decoder: JSONDecoder = .init(),
        logsEnabled: Bool = true
    ) {
        self.baseURL = baseURL
        self.session = session
        self.encoder = encoder
        self.decoder = decoder
        self.logsEnabled = logsEnabled
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func request<T: Decodable>(_ endpoint: APIEndpoint, as type: T.Type) async throws -> T {
        let request = try buildRequest(endpoint)
        logRequest(request)

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                logInvalidResponse(data: data)
                throw NetworkError.invalidResponse
            }

            logResponse(httpResponse, data: data)

            guard 200..<300 ~= httpResponse.statusCode else {
                let message = String(data: data, encoding: .utf8)
                throw NetworkError.http(statusCode: httpResponse.statusCode, message: message)
            }

            do {
                return try decodeResponse(T.self, from: data)
            } catch {
                throw NetworkError.decodingFailed
            }
        } catch let error as NetworkError {
            logError(error, request: request)
            throw error
        } catch {
            let networkError = NetworkError.transport(error)
            logError(networkError, request: request)
            throw networkError
        }
    }

    private func buildRequest(_ endpoint: APIEndpoint) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: false) else {
            throw NetworkError.invalidURL
        }

        if !endpoint.queryItems.isEmpty {
            components.queryItems = endpoint.queryItems
            components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        }

        guard let url = components.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        for (key, value) in endpoint.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        if let body = endpoint.body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(AnyEncodable(body))
        }

        return request
    }

    private func decodeResponse<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            let envelope = try decoder.decode(APIResponseEnvelope<T>.self, from: data)
            return envelope.data
        } catch {
            return try decoder.decode(T.self, from: data)
        }
    }

    private func logRequest(_ request: URLRequest) {
        guard logsEnabled else { return }
        print("API Request: \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "<invalid-url>")")

        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            print("API Request Headers: \(redacted(headers))")
        }

        if let body = request.httpBody, !body.isEmpty {
            logBody("API Request Body", data: body)
        }
    }

    private func logResponse(_ response: HTTPURLResponse, data: Data) {
        guard logsEnabled else { return }
        print("API Response: \(response.statusCode) \(response.url?.absoluteString ?? "<invalid-url>")")

        if !data.isEmpty {
            logBody("API Response Body", data: data)
        }
    }

    private func logInvalidResponse(data: Data) {
        guard logsEnabled else { return }
        print("API Response: invalid response")

        if !data.isEmpty {
            logBody("API Response Body", data: data)
        }
    }

    private func logError(_ error: Error, request: URLRequest) {
        guard logsEnabled else { return }
        print("API Error: \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "<invalid-url>") -> \(error.localizedDescription)")
    }

    private func logBody(_ label: String, data: Data) {
        for line in APILogFormatter.bodyLogLines(label: label, data: data) {
            print(line)
        }
    }

    private func redacted(_ headers: [String: String]) -> [String: String] {
        headers.reduce(into: [:]) { result, item in
            if item.key.lowercased() == "authorization" {
                result[item.key] = "<redacted>"
            } else {
                result[item.key] = item.value
            }
        }
    }
}

private struct APIResponseEnvelope<T: Decodable>: Decodable {
    let data: T
}

enum APILogFormatter {
    private static let chunkSize = 1_000

    static func bodyLogLines(label: String, data: Data) -> [String] {
        let body = redactedBodyString(from: data)
        let chunks = body.chunked(maxLength: chunkSize)
        guard chunks.count > 1 else {
            return ["\(label): \(body)"]
        }

        return ["\(label):"]
            + chunks.enumerated().map { index, chunk in
                "\(label) [\(index + 1)/\(chunks.count)]: \(chunk)"
            }
    }

    static func redactedBodyString(from data: Data) -> String {
        if let redacted = redactedJSONString(from: data) {
            return redacted
        }

        return String(data: data, encoding: .utf8) ?? "<\(data.count) bytes>"
    }

    private static func redactedJSONString(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) else { return nil }
        let redacted = redactSensitiveValues(in: object)
        guard let data = try? JSONSerialization.data(withJSONObject: redacted, options: [.prettyPrinted, .sortedKeys]) else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    private static func redactSensitiveValues(in value: Any) -> Any {
        if let dictionary = value as? [String: Any] {
            return dictionary.reduce(into: [String: Any]()) { result, item in
                let key = item.key.lowercased()
                if key.contains("password") || key.contains("token") || key == "authorization" {
                    result[item.key] = "<redacted>"
                } else {
                    result[item.key] = redactSensitiveValues(in: item.value)
                }
            }
        }

        if let array = value as? [Any] {
            return array.map { redactSensitiveValues(in: $0) }
        }

        return value
    }
}

private extension String {
    func chunked(maxLength: Int) -> [String] {
        guard count > maxLength else { return [self] }

        var chunks: [String] = []
        var start = startIndex

        while start < endIndex {
            let end = index(start, offsetBy: maxLength, limitedBy: endIndex) ?? endIndex
            chunks.append(String(self[start..<end]))
            start = end
        }

        return chunks
    }
}
