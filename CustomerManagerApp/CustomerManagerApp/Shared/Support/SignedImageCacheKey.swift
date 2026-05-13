import Foundation

enum SignedImageCacheKey {
    static func make(for url: URL) -> String {
        let query = url.query?.lowercased() ?? ""
        let isSignedURL = query.contains("q-signature=")
            || query.contains("q-sign-time=")
            || query.contains("q-key-time=")

        if isSignedURL, let host = url.host {
            return host + url.path
        }
        return url.absoluteString
    }
}
