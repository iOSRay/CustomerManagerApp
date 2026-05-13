import SwiftUI
import Kingfisher

@main
struct CustomerManagerApp: App {
    private let container = AppContainer.live

    init() {
        configureImagePipeline()
    }

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
        }
    }

    private func configureImagePipeline() {
        let downloader = KingfisherManager.shared.downloader
        downloader.downloadTimeout = 20

        let configuration = downloader.sessionConfiguration
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        downloader.sessionConfiguration = configuration

        let cache = ImageCache.default
        cache.memoryStorage.config.totalCostLimit = 80 * 1024 * 1024
        cache.diskStorage.config.sizeLimit = 500 * 1024 * 1024
    }
}
