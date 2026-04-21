import Foundation

struct DashboardStats: Codable {
    let soldDevices: Int
    let totalUsages: Int
    let activeDevices: Int

    var usageRate: Double {
        guard soldDevices > 0 else { return 0 }
        return Double(activeDevices) / Double(soldDevices)
    }
}
