import SwiftUI

struct ScanRecordDetailView: View {
    let record: ScanRecord

    var body: some View {
        List {
            Section("基础信息") {
                item("门店", record.storeName)
                item("联系人", record.contactName)
                item("城市", record.city)
                item("头发长度", record.hairLength)
                item("发色", record.hairColor)
                item("满意度", satisfactionText)
            }

            Section("配方结果逻辑") {
                Text(record.formula)
            }
        }
        .navigationTitle("扫描详情")
    }

    private var satisfactionText: String {
        guard record.satisfactionScore != nil else {
            return "未评价"
        }
        return record.satisfied ? "满意" : "不满意"
    }

    private func item(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}
