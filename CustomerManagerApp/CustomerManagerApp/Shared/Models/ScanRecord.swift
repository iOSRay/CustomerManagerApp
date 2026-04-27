import Foundation

struct ScanRecordPreviewImage: Codable, Hashable {
    let url: URL?
    let cacheKey: String?
    let prefersFitHeight: Bool
    let initialWidthRatio: Double?
    let accessibilityLabel: String?
}

struct ScanRecordFormulaDetailItem: Codable, Identifiable {
    let id: UUID
    let degree: String
    let part: String
    let formula: String
    let ratio: String
    let referenceId: String
    let delta: String
    let labValues: [String]
    let usesAlternateSwatch: Bool
    let previewImages: [ScanRecordPreviewImage]
}

struct ScanRecord: Codable, Identifiable {
    let id: UUID
    let deviceId: String?
    let storeName: String
    let contactName: String
    let city: String
    let scannedAt: Date
    let hairLength: String
    let hairColor: String
    let satisfied: Bool
    let formula: String
    let detailItems: [ScanRecordFormulaDetailItem]?
}
