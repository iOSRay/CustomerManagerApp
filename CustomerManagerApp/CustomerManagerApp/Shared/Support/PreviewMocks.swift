import Foundation

enum PreviewMocks {
    static let stats = DashboardStats(soldDevices: 120, totalUsages: 3420, activeDevices: 98)

    static let records: [ScanRecord] = [
        ScanRecord(
            id: UUID(),
            deviceId: "D001",
            storeName: "上海静安店",
            contactName: "王店长",
            city: "上海",
            scannedAt: Date(),
            hairLength: "中长",
            hairColor: "冷棕",
            satisfied: true,
            formula: "底色6度 + 3%双氧；6N:6A=2:1；停留28分钟。",
            detailItems: [
                ScanRecordFormulaDetailItem(
                    id: UUID(),
                    degree: "8.5度",
                    part: "根部 8.0cm",
                    formula: "配方：6N + 6A + 0/00 + 3%",
                    ratio: "比例：2 : 2 : 1 : 10 : 15",
                    referenceId: "参考发条id: A1794-1",
                    delta: "Delta: 0.32",
                    labValues: ["Lab: 62.1, 7.8, 18.4", "Lab: 63.4, 8.1, 17.9"],
                    usesAlternateSwatch: false,
                    previewImages: [
                        ScanRecordPreviewImage(
                            url: URL(string: "https://picsum.photos/seed/customer-hair-root-1/480/720"),
                            cacheKey: "customer-hair-root-1",
                            rotates90CW: true,
                            prefersFitHeight: true,
                            initialWidthRatio: nil,
                            accessibilityLabel: "根部参考图一"
                        ),
                        ScanRecordPreviewImage(
                            url: URL(string: "https://picsum.photos/seed/customer-hair-root-2/480/720"),
                            cacheKey: "customer-hair-root-2",
                            rotates90CW: false,
                            prefersFitHeight: true,
                            initialWidthRatio: nil,
                            accessibilityLabel: "根部参考图二"
                        )
                    ]
                ),
                ScanRecordFormulaDetailItem(
                    id: UUID(),
                    degree: "8.0度",
                    part: "尾部 6.7cm",
                    formula: "配方：6/77 + 8/65 + 4/0 + 00 + 3%",
                    ratio: "比例：3 : 3 : 2 : 24 : 32",
                    referenceId: "参考发条id: ZA887-3",
                    delta: "Delta: 0.47",
                    labValues: ["Lab: 59.6, 9.2, 16.5", "Lab: 60.1, 8.9, 15.8"],
                    usesAlternateSwatch: true,
                    previewImages: [
                        ScanRecordPreviewImage(
                            url: URL(string: "https://picsum.photos/seed/customer-hair-tail-1/480/720"),
                            cacheKey: "customer-hair-tail-1",
                            rotates90CW: true,
                            prefersFitHeight: true,
                            initialWidthRatio: nil,
                            accessibilityLabel: "尾部参考图一"
                        ),
                        ScanRecordPreviewImage(
                            url: URL(string: "https://picsum.photos/seed/customer-hair-tail-2/480/720"),
                            cacheKey: "customer-hair-tail-2",
                            rotates90CW: false,
                            prefersFitHeight: true,
                            initialWidthRatio: nil,
                            accessibilityLabel: "尾部参考图二"
                        )
                    ]
                )
            ]
        )
    ]
}
