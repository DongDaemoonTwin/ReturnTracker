import SwiftData
import SwiftUI

struct ItemsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(
        sort: [
            SortDescriptor(\ReturnItem.returnDeadline),
            SortDescriptor(\ReturnItem.createdAt, order: .reverse)
        ]
    ) private var items: [ReturnItem]

    @Query private var histories: [ReturnStatusHistory]

    @State private var searchText = ""
    @State private var now = Date.now
    @State private var errorMessage: String?

    private var filteredItems: [ReturnItem] {
        guard !searchText.isEmpty else { return items }
        return items.filter {
            $0.productName.localizedStandardContains(searchText) ||
                $0.storeName.localizedStandardContains(searchText) ||
                ($0.orderNumber?.localizedStandardContains(searchText) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView(
                        "등록된 상품이 없습니다",
                        systemImage: "shippingbox",
                        description: Text("홈에서 첫 상품을 추가해 보세요.")
                    )
                } else if filteredItems.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List {
                        ForEach(filteredItems) { item in
                            NavigationLink {
                                ItemDetailView(item: item)
                            } label: {
                                ReturnItemRow(item: item, now: now)
                            }
                        }
                        .onDelete(perform: deleteItems)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("전체 상품")
            .searchable(text: $searchText, prompt: "상품명, 구매처, 주문번호")
            .alert(
                "삭제할 수 없습니다",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "알 수 없는 오류가 발생했습니다.")
            }
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        let deletedItems = offsets.map { filteredItems[$0] }

        do {
            for item in deletedItems {
                histories
                    .filter { $0.itemID == item.id }
                    .forEach { modelContext.delete($0) }
                modelContext.delete(item)
            }
            try modelContext.save()

            for item in deletedItems {
                NotificationService.shared.cancel(itemID: item.id)
            }
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}
