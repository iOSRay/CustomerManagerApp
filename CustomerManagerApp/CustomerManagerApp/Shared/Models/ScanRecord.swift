import Foundation

struct ScanRecordPreviewImage: Codable, Hashable {
    let url: URL?
    let cacheKey: String?
    let prefersFitHeight: Bool
    let initialWidthRatio: Double?
    let accessibilityLabel: String?
}

struct ScanRecordFormulaDetailItem: Codable, Identifiable {
    let id: UUID
    let degree: String
    let part: String
    let formula: String
    let ratio: String
    let referenceId: String
    let delta: String
    let labValues: [String]
    let usesAlternateSwatch: Bool
    let previewImages: [ScanRecordPreviewImage]
}

struct ScanRecord: Decodable, Identifiable {
    let id: UUID
    let workId: Int?
    let deviceId: String?
    let storeName: String
    let contactName: String
    let city: String
    let scannedAt: Date
    let hairLength: String
    let hairColor: String
    let baseLevelText: String?
    let hairColorImageURL: URL?
    let segmentCount: Int?
    let satisfactionScore: Double?
    let satisfied: Bool
    let formula: String
    let detailItems: [ScanRecordFormulaDetailItem]?

    init(
        id: UUID,
        workId: Int? = nil,
        deviceId: String?,
        storeName: String,
        contactName: String,
        city: String,
        scannedAt: Date,
        hairLength: String,
        hairColor: String,
        baseLevelText: String? = nil,
        hairColorImageURL: URL? = nil,
        segmentCount: Int? = nil,
        satisfactionScore: Double? = nil,
        satisfied: Bool,
        formula: String,
        detailItems: [ScanRecordFormulaDetailItem]?
    ) {
        self.id = id
        self.workId = workId
        self.deviceId = deviceId
        self.storeName = storeName
        self.contactName = contactName
        self.city = city
        self.scannedAt = scannedAt
        self.hairLength = hairLength
        self.hairColor = hairColor
        self.baseLevelText = baseLevelText
        self.hairColorImageURL = hairColorImageURL
        self.segmentCount = segmentCount
        self.satisfactionScore = satisfactionScore
        self.satisfied = satisfied
        self.formula = formula
        self.detailItems = detailItems
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let hairItem = try container.decodeIfPresent(HairItemPayload.self, forKey: .hairItem)
        let hairColorPayload: HairColorPayload?
        if let payload = try? container.decodeIfPresent(HairColorPayload.self, forKey: .hairColorSnake) {
            hairColorPayload = payload
        } else {
            hairColorPayload = nil
        }
        let segments = try container.decodeIfPresent([SegmentPayload].self, forKey: .segments) ?? []

        workId = try container.decodeFlexibleIntIfPresent(forKeys: [.workId, .workIdSnake, .hairDyeWorkId, .id])
        id = (try? container.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        deviceId = try container.decodeFlexibleStringIfPresent(forKeys: [.deviceId, .deviceIdSnake, .deviceCode, .deviceUid]) ?? hairItem?.deviceId
        storeName = try container.decodeFlexibleString(forKeys: [.storeName, .storeNameSnake], defaultValue: "")
        contactName = try container.decodeFlexibleString(forKeys: [.contactName, .contactPerson, .contactPersonSnake], defaultValue: "")
        city = try container.decodeFlexibleString(forKeys: [.city, .address], defaultValue: "")
        scannedAt = try container.decodeFlexibleDate(forKeys: [.scannedAt, .scannedAtSnake, .scanTime, .createdAt, .createdAtSnake, .uploadedAt, .uploadedAtSnake], fallback: hairItem?.uploadTime)
        hairLength = try container.decodeHairLength(fallback: hairItem?.physicalLength)
        let decodedHairColor = try container.decodeFlexibleString(forKeys: [.hairColor, .hairColorSnake, .targetColor, .targetColorSnake, .selectedHairColorName], defaultValue: hairColorPayload?.colorName ?? "")
        hairColor = decodedHairColor
        baseLevelText = hairColorPayload?.baseLevelText
        let gender = try container.decodeFlexibleStringIfPresent(forKeys: [.gender])
        hairColorImageURL = hairColorPayload?.imageURL(for: gender)
        segmentCount = try container.decodeFlexibleIntIfPresent(forKeys: [.segmentCount])
        satisfactionScore = try container.decodeFlexibleDoubleIfPresent(forKeys: [.satisfactionScore])
        satisfied = try container.decodeSatisfaction(score: satisfactionScore, segments: segments)
        formula = try container.decodeFlexibleString(forKeys: [.formula], defaultValue: segments.compactMap(\.recipe?.formula).first ?? "")
        detailItems = try container.decodeIfPresent([ScanRecordFormulaDetailItem].self, forKey: .detailItems)
            ?? container.decodeIfPresent([ScanRecordFormulaDetailItem].self, forKey: .detailItemsSnake)
            ?? segments.map { $0.detailItem() }
    }

    fileprivate enum CodingKeys: String, CodingKey {
        case id
        case workId
        case workIdSnake = "work_id"
        case hairDyeWorkId = "hair_dye_work_id"
        case deviceId
        case deviceIdSnake = "device_id"
        case deviceCode = "device_code"
        case deviceUid = "device_uid"
        case storeName
        case storeNameSnake = "store_name"
        case contactName
        case contactPerson = "contactPerson"
        case contactPersonSnake = "contact_person"
        case city
        case address
        case scannedAt
        case scannedAtSnake = "scanned_at"
        case scanTime = "scan_time"
        case createdAt
        case createdAtSnake = "created_at"
        case uploadedAt
        case uploadedAtSnake = "uploaded_at"
        case hairLength
        case hairLengthSnake = "hair_length"
        case hairLengthCm = "hair_length_cm"
        case hairColor
        case hairColorSnake = "hair_color"
        case targetColor = "targetColor"
        case targetColorSnake = "target_color"
        case selectedHairColorName = "selected_hair_color_name"
        case gender
        case segmentCount = "segment_count"
        case satisfied
        case satisfactionScore = "satisfaction_score"
        case formula
        case detailItems
        case detailItemsSnake = "detail_items"
        case hairItem = "hair_item"
        case segments
    }
}

private extension KeyedDecodingContainer where K == ScanRecord.CodingKeys {
    func decodeFlexibleString(forKeys keys: [K], defaultValue: String) throws -> String {
        try decodeFlexibleStringIfPresent(forKeys: keys) ?? defaultValue
    }

    func decodeFlexibleStringIfPresent(forKeys keys: [K]) throws -> String? {
        for key in keys {
            if let value = try? decodeIfPresent(String.self, forKey: key) {
                return value
            }
            if let value = try? decodeIfPresent(Int.self, forKey: key) {
                return "\(value)"
            }
            if let value = try? decodeIfPresent(Double.self, forKey: key) {
                return value.cleanDecimalText
            }
        }
        return nil
    }

    func decodeHairLength(fallback: Double?) throws -> String {
        if let text = try decodeFlexibleStringIfPresent(forKeys: [.hairLength, .hairLengthSnake]) {
            return text
        }
        if let value = try decodeIfPresent(Double.self, forKey: .hairLengthCm) {
            return "\(value.cleanDecimalText)cm"
        }
        if let value = try decodeIfPresent(Int.self, forKey: .hairLengthCm) {
            return "\(value)cm"
        }
        if let fallback {
            return "\(fallback.cleanDecimalText)cm"
        }
        return ""
    }

    func decodeSatisfaction(score: Double?, segments: [SegmentPayload]) throws -> Bool {
        if let value = try decodeIfPresent(Bool.self, forKey: .satisfied) {
            return value
        }
        if let value = score {
            return value >= 4
        }
        if !segments.isEmpty {
            return segments.allSatisfy { $0.matchStatus == 1 }
        }
        return false
    }

    func decodeFlexibleDoubleIfPresent(forKeys keys: [K]) throws -> Double? {
        for key in keys {
            if let value = try decodeIfPresent(Double.self, forKey: key) {
                return value
            }
            if let value = try decodeIfPresent(Int.self, forKey: key) {
                return Double(value)
            }
            if let value = try decodeIfPresent(String.self, forKey: key), let doubleValue = Double(value) {
                return doubleValue
            }
        }
        return nil
    }

    func decodeFlexibleIntIfPresent(forKeys keys: [K]) throws -> Int? {
        for key in keys {
            if let value = try decodeIfPresent(Int.self, forKey: key) {
                return value
            }
            if let value = try decodeIfPresent(String.self, forKey: key), let intValue = Int(value) {
                return intValue
            }
        }
        return nil
    }

    func decodeFlexibleDate(forKeys keys: [K], fallback: Date? = nil) throws -> Date {
        for key in keys {
            if let value = try? decodeIfPresent(Date.self, forKey: key) {
                return value
            }
            if let value = try decodeIfPresent(String.self, forKey: key) {
                if let date = ISO8601DateFormatter.fractionalSeconds.date(from: value) ?? ISO8601DateFormatter.internetDateTime.date(from: value) {
                    return date
                }
            }
        }
        return fallback ?? Date()
    }
}

private extension Double {
    var cleanDecimalText: String {
        let rounded = rounded()
        if abs(self - rounded) < 0.000001 {
            return "\(Int(rounded))"
        }
        return String(format: "%.1f", self)
    }
}

private struct HairItemPayload: Decodable {
    let deviceId: String?
    let physicalLength: Double?
    let uploadTime: Date?

    private enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case physicalLength = "physical_length"
        case uploadTime = "upload_time"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        deviceId = try container.decodeIfPresent(String.self, forKey: .deviceId)
        physicalLength = try container.decodeIfPresent(Double.self, forKey: .physicalLength)
        if let value = try container.decodeIfPresent(String.self, forKey: .uploadTime) {
            uploadTime = ISO8601DateFormatter.fractionalSeconds.date(from: value) ?? ISO8601DateFormatter.internetDateTime.date(from: value)
        } else {
            uploadTime = nil
        }
    }
}

private struct HairColorPayload: Decodable {
    let colorName: String?
    let baseLevelMin: Double?
    let baseLevelMax: Double?
    let femaleImageURL: URL?
    let maleImageURL: URL?

    var baseLevelText: String? {
        guard let baseLevelMin, let baseLevelMax else {
            return nil
        }
        return "\(baseLevelMin.cleanDecimalText)-\(baseLevelMax.cleanDecimalText)度"
    }

    func imageURL(for gender: String?) -> URL? {
        if gender?.uppercased() == "MALE" {
            return maleImageURL ?? femaleImageURL
        }
        return femaleImageURL ?? maleImageURL
    }

    private enum CodingKeys: String, CodingKey {
        case colorName = "color_name"
        case baseLevelMin = "base_level_min"
        case baseLevelMax = "base_level_max"
        case femaleImageURL = "female_image"
        case maleImageURL = "male_image"
    }
}

private struct SegmentPayload: Decodable {
    let serialNumber: Int
    let baseDegree: Double?
    let imageURL: URL?
    let referImageURL: URL?
    let referLab: LabPayload?
    let sampledLab: LabPayload?
    let referUID: String?
    let matchStatus: Int?
    let segmentLength: Double?
    let noRecipeReason: String?
    let recipe: RecipePayload?

    private enum CodingKeys: String, CodingKey {
        case serialNumber = "serial_number"
        case baseDegree = "base_degree"
        case imageURL = "image_url"
        case referImageURL = "refer_image_url"
        case referLab = "refer_lab"
        case sampledLab = "sampled_lab"
        case referUID = "refer_uid"
        case matchStatus = "match_status"
        case segmentLength = "segment_length"
        case noRecipeReason = "no_recipe_reason"
        case recipe
    }

    func detailItem() -> ScanRecordFormulaDetailItem {
        var previewImages: [ScanRecordPreviewImage] = []
        var labValues: [String] = []

        if let imageURL {
            previewImages.append(
                ScanRecordPreviewImage(
                    url: imageURL,
                    cacheKey: imageURL.absoluteString,
                    prefersFitHeight: true,
                    initialWidthRatio: nil,
                    accessibilityLabel: "第\(serialNumber)段图片"
                )
            )
            labValues.append(sampledLab?.displayText ?? "")
        }

        if let referImageURL {
            previewImages.append(
                ScanRecordPreviewImage(
                    url: referImageURL,
                    cacheKey: referImageURL.absoluteString,
                    prefersFitHeight: true,
                    initialWidthRatio: nil,
                    accessibilityLabel: "第\(serialNumber)段参考发条图"
                )
            )
            labValues.append(referLab?.displayText ?? "")
        }

        return ScanRecordFormulaDetailItem(
            id: UUID(),
            degree: baseDegree.map { "\($0.cleanDecimalText)度" } ?? "",
            part: "第\(serialNumber)段 \(segmentLength.map { "\($0.cleanDecimalText)cm" } ?? "")",
            formula: recipe.map { "配方：\($0.formula)" } ?? (noRecipeReason ?? "暂无配方"),
            ratio: recipe.map { "比例：\($0.ratios)" } ?? "",
            referenceId: referUID.map { "参考发条id: \($0)" } ?? "",
            delta: deltaText,
            labValues: labValues,
            usesAlternateSwatch: serialNumber.isMultiple(of: 2),
            previewImages: previewImages
        )
    }

    private var deltaText: String {
        guard let sampledLab, let referLab else {
            return ""
        }
        return "Delta: \(sampledLab.lDelta(to: referLab).cleanDecimalText)"
    }
}

private struct LabPayload: Decodable {
    let lValue: Double
    let aValue: Double
    let bValue: Double

    var displayText: String {
        "Lab: \(lValue.cleanDecimalText), \(aValue.cleanDecimalText), \(bValue.cleanDecimalText)"
    }

    func lDelta(to other: LabPayload) -> Double {
        abs(lValue - other.lValue)
    }

    private enum CodingKeys: String, CodingKey {
        case lValue = "l_value"
        case aValue = "a_value"
        case bValue = "b_value"
    }
}

private struct RecipePayload: Decodable {
    let formula: String
    let ratios: String
    let components: [RecipeComponentPayload]
}

private struct RecipeComponentPayload: Decodable {
    let name: String
    let grams: Double
}

private extension ISO8601DateFormatter {
    static let fractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let internetDateTime: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
