import XCTest
@testable import CustomerManagerApp

final class CustomerManagerAppTests: XCTestCase {
    func testUsageRateCalculation() {
        let stats = DashboardStats(soldDevices: 10, totalUsages: 40, activeDevices: 4)
        XCTAssertEqual(stats.usageRate, 0.4, accuracy: 0.0001)
    }

    func testSignedImageCacheKeyIgnoresExpiringSignature() throws {
        let first = try XCTUnwrap(URL(string: "https://example.com/image.png?q-sign-time=1%3B2&q-signature=first"))
        let second = try XCTUnwrap(URL(string: "https://example.com/image.png?q-sign-time=3%3B4&q-signature=second"))

        XCTAssertEqual(SignedImageCacheKey.make(for: first), SignedImageCacheKey.make(for: second))
    }

    func testSignedImageCacheKeySeparatesOriginalAndProcessedImages() throws {
        let original = try XCTUnwrap(URL(string: "https://example.com/image.png?q-signature=original"))
        let thumbnail = try XCTUnwrap(URL(string: "https://example.com/image.png?q-signature=thumbnail&imageMogr2%2Fthumbnail%2F1280x720%3E="))

        XCTAssertNotEqual(SignedImageCacheKey.make(for: original), SignedImageCacheKey.make(for: thumbnail))
        XCTAssertTrue(SignedImageCacheKey.make(for: thumbnail).contains("imageMogr2"))
    }

    func testSignedImageCacheKeySeparatesProcessingVariants() throws {
        let webp = try XCTUnwrap(URL(string: "https://example.com/image.png?q-signature=one&imageMogr2%2Fformat%2Fwebp="))
        let jpeg = try XCTUnwrap(URL(string: "https://example.com/image.png?q-signature=two&imageMogr2%2Fformat%2Fjpg="))

        XCTAssertNotEqual(SignedImageCacheKey.make(for: webp), SignedImageCacheKey.make(for: jpeg))
    }

    func testUnsignedImageCacheKeyRemainsUnchanged() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/image.png?size=large"))

        XCTAssertEqual(SignedImageCacheKey.make(for: url), url.absoluteString)
    }

    func testAPILogFormatterDoesNotTruncateLongJSON() throws {
        let longValue = String(repeating: "a", count: 5_000)
        let data = try JSONSerialization.data(
            withJSONObject: ["message": longValue, "token": "secret"],
            options: []
        )

        let output = APILogFormatter.redactedBodyString(from: data)

        XCTAssertTrue(output.contains(longValue))
        XCTAssertFalse(output.contains("truncated"))
        XCTAssertFalse(output.contains("secret"))
        XCTAssertTrue(output.contains("<redacted>"))
    }
}
