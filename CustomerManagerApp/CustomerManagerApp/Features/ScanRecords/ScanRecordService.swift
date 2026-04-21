import Foundation

protocol ScanRecordServiceProtocol {
    func fetchRecords(store: String?, city: String?, contact: String?) async throws -> [ScanRecord]
}

struct ScanRecordEndpoint: APIEndpoint {
    let path: String = "/v1/scan-records"
    let method: HTTPMethod = .get
    let queryItems: [URLQueryItem]

    init(store: String?, city: String?, contact: String?) {
        var items: [URLQueryItem] = []
        if let store, !store.isEmpty { items.append(.init(name: "store", value: store)) }
        if let city, !city.isEmpty { items.append(.init(name: "city", value: city)) }
        if let contact, !contact.isEmpty { items.append(.init(name: "contact", value: contact)) }
        queryItems = items
    }
}

final class ScanRecordService: ScanRecordServiceProtocol {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func fetchRecords(store: String?, city: String?, contact: String?) async throws -> [ScanRecord] {
        try await apiClient.request(ScanRecordEndpoint(store: store, city: city, contact: contact), as: [ScanRecord].self)
    }
}
