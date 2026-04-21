import SwiftUI

struct RootView: View {
    let container: AppContainer

    var body: some View {
        DashboardView(
            dashboardViewModel: DashboardViewModel(statsService: container.statsService),
            scanViewModel: ScanRecordListViewModel(scanRecordService: container.scanRecordService)
        )
    }
}
