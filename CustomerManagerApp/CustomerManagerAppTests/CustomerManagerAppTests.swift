import XCTest
@testable import CustomerManagerApp

final class CustomerManagerAppTests: XCTestCase {
    func testUsageRateCalculation() {
        let stats = DashboardStats(soldDevices: 10, totalUsages: 40, activeDevices: 4)
        XCTAssertEqual(stats.usageRate, 0.4, accuracy: 0.0001)
    }
}
