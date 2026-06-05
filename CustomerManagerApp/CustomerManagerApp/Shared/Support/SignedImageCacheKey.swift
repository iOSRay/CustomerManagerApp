import Foundation

enum SignedImageCacheKey {
    private static let cacheVersion = "signed-image-v2"
    private static let signatureQueryNames: Set<String> = [
        "q-sign-algorithm",
        "q-ak",
        "q-sign-time",
        "q-key-time",
        "q-header-list",
        "q-url-param-list",
        "q-signature"
    ]

    static func make(for url: URL) -> String {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.absoluteString
        }

        let queryItems = components.queryItems ?? []
        let isSignedURL = queryItems.contains {
            signatureQueryNames.contains($0.name.lowercased())
        }

        if isSignedURL, let host = url.host {
            let contentQueryItems = queryItems
                .filter { !signatureQueryNames.contains($0.name.lowercased()) }
                .sorted {
                    if $0.name == $1.name {
                        return ($0.value ?? "") < ($1.value ?? "")
                    }
                    return $0.name < $1.name
                }

            let contentVariant = canonicalQuery(from: contentQueryItems)
            let baseKey = "\(cacheVersion):\(host.lowercased())\(url.path)"
            return contentVariant.isEmpty ? baseKey : "\(baseKey)?\(contentVariant)"
        }
        return url.absoluteString
    }

    private static func canonicalQuery(from queryItems: [URLQueryItem]) -> String {
        guard !queryItems.isEmpty else { return "" }

        var components = URLComponents()
        components.queryItems = queryItems
        return components.percentEncodedQuery ?? ""
    }
}
