import Foundation

struct DashboardStats: Codable {
    let soldDevices: Int
    let totalUsages: Int
    let activeDevices: Int

    var usageRate: Double {
        guard soldDevices > 0 else { return 0 }
        return Double(activeDevices) / Double(soldDevices)
    }

    init(soldDevices: Int, totalUsages: Int, activeDevices: Int) {
        self.soldDevices = soldDevices
        self.totalUsages = totalUsages
        self.activeDevices = activeDevices
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        soldDevices = try container.decodeFlexibleInt(forKeys: [.soldDevices, .soldDevicesSnake, .soldDeviceCount, .totalSoldDevices, .totalDevices])
        totalUsages = try container.decodeFlexibleInt(forKeys: [.totalUsages, .totalUsagesSnake, .totalUses, .usageCount, .totalUsageCount])
        activeDevices = try container.decodeFlexibleInt(forKeys: [.activeDevices, .activeDevicesSnake, .usedDeviceCount, .devicesUsedAtLeastOnce, .devicesUsed])
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(soldDevices, forKey: .soldDevices)
        try container.encode(totalUsages, forKey: .totalUsages)
        try container.encode(activeDevices, forKey: .activeDevices)
    }

    fileprivate enum CodingKeys: String, CodingKey {
        case soldDevices
        case soldDevicesSnake = "sold_devices"
        case soldDeviceCount = "sold_device_count"
        case totalSoldDevices = "total_sold_devices"
        case totalDevices = "total_devices"
        case totalUsages
        case totalUsagesSnake = "total_usages"
        case totalUses = "total_uses"
        case usageCount = "usage_count"
        case totalUsageCount = "total_usage_count"
        case activeDevices
        case activeDevicesSnake = "active_devices"
        case usedDeviceCount = "used_device_count"
        case devicesUsedAtLeastOnce = "devices_used_at_least_once"
        case devicesUsed = "devices_used"
    }
}

private extension KeyedDecodingContainer where K == DashboardStats.CodingKeys {
    func decodeFlexibleInt(forKeys keys: [K]) throws -> Int {
        for key in keys {
            if let value = try decodeIfPresent(Int.self, forKey: key) {
                return value
            }
            if let value = try decodeIfPresent(Double.self, forKey: key) {
                return Int(value)
            }
            if let value = try decodeIfPresent(String.self, forKey: key), let intValue = Int(value) {
                return intValue
            }
        }
        throw DecodingError.keyNotFound(
            keys[0],
            DecodingError.Context(codingPath: codingPath, debugDescription: "Missing usage stats value")
        )
    }
}
