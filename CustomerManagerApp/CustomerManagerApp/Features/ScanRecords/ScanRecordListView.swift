import SwiftUI

struct ScanRecordListView: View {
    @StateObject private var viewModel: ScanRecordListViewModel
    @State private var showFilterSheet = false

    init(viewModel: ScanRecordListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List {
            if let notice = viewModel.noticeMessage {
                Text(notice)
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .padding(.vertical, 4)
            }

            switch viewModel.state {
            case .idle, .loading:
                EmptyView()
            case let .failed(message):
                Text(message).foregroundStyle(.red)
            case let .loaded(records):
                if records.isEmpty {
                    ContentUnavailableView("暂无记录", systemImage: "tray")
                } else {
                    ForEach(records) { record in
                        NavigationLink {
                            ScanRecordDetailView(record: record)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(record.storeName).bold()
                                Text("\(record.city) · \(record.contactName) · \(record.hairLength) · \(record.hairColor)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("扫描记录")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("筛选") { showFilterSheet = true }
            }
        }
        .sheet(isPresented: $showFilterSheet) {
            NavigationStack {
                Form {
                    TextField("门店名称", text: $viewModel.filter.store)
                    TextField("城市", text: $viewModel.filter.city)
                    TextField("联系人", text: $viewModel.filter.contact)
                }
                .navigationTitle("筛选条件")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("关闭") { showFilterSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("应用") {
                            showFilterSheet = false
                            Task { await viewModel.load() }
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .task {
            await viewModel.load()
        }
        .loadingHUD(viewModel.isRequesting)
    }
}
