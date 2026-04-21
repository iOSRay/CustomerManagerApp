import SwiftUI

@main
struct CustomerManagerApp: App {
    private let container = AppContainer.live

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
        }
    }
}
