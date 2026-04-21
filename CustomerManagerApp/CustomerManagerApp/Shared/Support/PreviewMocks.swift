import Foundation

enum PreviewMocks {
    static let stats = DashboardStats(soldDevices: 120, totalUsages: 3420, activeDevices: 98)

    static let records: [ScanRecord] = [
        ScanRecord(
            id: UUID(),
            deviceId: "D001",
            storeName: "上海静安店",
            contactName: "王店长",
            city: "上海",
            scannedAt: Date(),
            hairLength: "中长",
            hairColor: "冷棕",
            satisfied: true,
            formula: "底色6度 + 3%双氧；6N:6A=2:1；停留28分钟。"
        )
    ]
}
