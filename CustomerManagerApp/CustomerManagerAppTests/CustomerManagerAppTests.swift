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

    func testScanRecordSegmentUsesAPIDeltaValue() throws {
        let data = """
        {
          "store_name": "门店",
          "contact_person": "联系人",
          "city": "城市",
          "created_at": "2026-06-11T14:41:16Z",
          "hair_length": "10cm",
          "hair_color": "目标色",
          "segments": [
            {
              "serial_number": 1,
              "base_degree": 8.25,
              "delta_value": 34.200000000000003,
              "match_status": 1,
              "refer_uid": "SA1867-9W",
              "sampled_lab": {
                "l_value": 65.94,
                "a_value": -3.3,
                "b_value": 24.72
              },
              "refer_lab": {
                "l_value": 70.05,
                "a_value": -5.37,
                "b_value": 22.63
              },
              "recipe": {
                "formula": "0/11+6/77+0/45+00+3%=2:1:1:24:28",
                "ratios": "2:1:1:24:28",
                "components": []
              }
            }
          ]
        }
        """.data(using: .utf8)!

        let record = try JSONDecoder().decode(ScanRecord.self, from: data)

        XCTAssertEqual(record.detailItems?.first?.delta, "Delta: 34.20")
    }
}
