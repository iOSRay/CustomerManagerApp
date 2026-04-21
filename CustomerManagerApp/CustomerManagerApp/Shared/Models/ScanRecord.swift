import Foundation

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
}
