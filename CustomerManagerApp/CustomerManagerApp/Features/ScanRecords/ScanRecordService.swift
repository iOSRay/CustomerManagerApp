import Foundation

protocol ScanRecordServiceProtocol {
    func fetchRecords(filter: ScanRecordQuery) async throws -> ScanRecordPage
    func fetchRecordDetail(workId: Int) async throws -> ScanRecord
}

struct ScanRecordPage {
    let records: [ScanRecord]
    let page: Int
    let size: Int
    let total: Int?
}

struct ScanRecordQuery {
    var page: Int = 1
    var size: Int = 20
    var startTime: Date?
    var endTime: Date?
    var storeName: String = ""
    var city: String = ""
    var contactPerson: String = ""
}

struct ScanRecordEndpoint: APIEndpoint {
    let path: String = "/v1/admin/hair-dye-work/scan-records"
    let method: HTTPMethod = .get
    let queryItems: [URLQueryItem]
    let headers: [String: String]

    init(query: ScanRecordQuery, authorization: String) {
        var items: [URLQueryItem] = [
            .init(name: "page", value: "\(max(1, query.page))"),
            .init(name: "size", value: "\(min(max(1, query.size), 100))")
        ]
        if let startTime = query.startTime {
            items.append(.init(name: "start_time", value: Self.dateFormatter.string(from: startTime)))
        }
        if let endTime = query.endTime {
            items.append(.init(name: "end_time", value: Self.dateFormatter.string(from: endTime)))
        }
        if !query.storeName.isEmpty {
            items.append(.init(name: "store_name", value: query.storeName))
        }
        if !query.city.isEmpty {
            items.append(.init(name: "city", value: query.city))
        }
        if !query.contactPerson.isEmpty {
            items.append(.init(name: "contact_person", value: query.contactPerson))
        }
        queryItems = items
        headers = ["Authorization": authorization]
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        return formatter
    }()
}

struct ScanRecordDetailEndpoint: APIEndpoint {
    let path: String
    let method: HTTPMethod = .get
    let headers: [String: String]

    init(workId: Int, authorization: String) {
        path = "/v1/admin/hair-dye-work/scan-records/\(workId)"
        headers = ["Authorization": authorization]
    }
}

private struct ScanRecordListResponse: Decodable {
    let records: [ScanRecord]
    let page: Int?
    let size: Int?
    let total: Int?

    init(from decoder: Decoder) throws {
        if let records = try? [ScanRecord](from: decoder) {
            self.records = records
            page = nil
            size = nil
            total = nil
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let data = try container.decodeIfPresent(ScanRecordListResponse.self, forKey: .data) {
            self.records = data.records
            page = data.page
            size = data.size
            total = data.total
        } else if let records = try container.decodeIfPresent([ScanRecord].self, forKey: .records) {
            self.records = records
            page = try Self.decodeFlexibleIntIfPresent(in: container, forKey: .page)
            size = try Self.decodeFlexibleIntIfPresent(in: container, forKey: .size)
            total = try Self.decodeFlexibleIntIfPresent(in: container, forKey: .total)
        } else if let records = try container.decodeIfPresent([ScanRecord].self, forKey: .items) {
            self.records = records
            page = try Self.decodeFlexibleIntIfPresent(in: container, forKey: .page)
            size = try Self.decodeFlexibleIntIfPresent(in: container, forKey: .size)
            total = try Self.decodeFlexibleIntIfPresent(in: container, forKey: .total)
        } else if let records = try container.decodeIfPresent([ScanRecord].self, forKey: .list) {
            self.records = records
            page = try Self.decodeFlexibleIntIfPresent(in: container, forKey: .page)
            size = try Self.decodeFlexibleIntIfPresent(in: container, forKey: .size)
            total = try Self.decodeFlexibleIntIfPresent(in: container, forKey: .total)
        } else if let records = try container.decodeIfPresent([ScanRecord].self, forKey: .rows) {
            self.records = records
            page = try Self.decodeFlexibleIntIfPresent(in: container, forKey: .page)
            size = try Self.decodeFlexibleIntIfPresent(in: container, forKey: .size)
            total = try Self.decodeFlexibleIntIfPresent(in: container, forKey: .total)
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.list,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Missing scan record list")
            )
        }
    }

    private enum CodingKeys: String, CodingKey {
        case data
        case records
        case items
        case list
        case rows
        case page
        case size
        case total
    }

    private static func decodeFlexibleIntIfPresent(
        in container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) throws -> Int? {
        if let value = try container.decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let value = try container.decodeIfPresent(String.self, forKey: key), let intValue = Int(value) {
            return intValue
        }
        return nil
    }
}

final class ScanRecordService: ScanRecordServiceProtocol {
    private let apiClient: APIClientProtocol
    private let authService: AdminAuthServiceProtocol

    init(apiClient: APIClientProtocol, authService: AdminAuthServiceProtocol) {
        self.apiClient = apiClient
        self.authService = authService
    }

    func fetchRecords(filter: ScanRecordQuery) async throws -> ScanRecordPage {
        let authorization = try await authService.authorizationHeader()
        let response = try await apiClient.request(
            ScanRecordEndpoint(query: filter, authorization: authorization),
            as: ScanRecordListResponse.self
        )
        return ScanRecordPage(
            records: response.records,
            page: response.page ?? filter.page,
            size: response.size ?? filter.size,
            total: response.total
        )
    }

    func fetchRecordDetail(workId: Int) async throws -> ScanRecord {
        let authorization = try await authService.authorizationHeader()
        return try await apiClient.request(
            ScanRecordDetailEndpoint(workId: workId, authorization: authorization),
            as: ScanRecord.self
        )
    }
}
