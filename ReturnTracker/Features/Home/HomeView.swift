import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.scenePhase) private var scenePhase

    @Query(
        sort: [
            SortDescriptor(\ReturnItem.returnDeadline),
            SortDescriptor(\ReturnItem.createdAt, order: .reverse)
        ]
    ) private var items: [ReturnItem]

    @State private var isPresentingAddItem = false
    @State private var now = Date.now

    private var needsAttentionItems: [ReturnItem] {
        items.filter {
            ReturnDeadline.needsAttention(
                deadline: $0.returnDeadline,
                status: $0.status,
                now: now
            )
        }
    }

    private var recentItems: [ReturnItem] {
        Array(
            items
                .sorted { $0.createdAt > $1.createdAt }
                .filter { item in
                    !needsAttentionItems.contains { $0.id == item.id }
                }
                .prefix(5)
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    emptyState
                } else {
                    itemList
                }
            }
            .navigationTitle("반품 관리")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingAddItem = true
                    } label: {
                        Label("상품 추가", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isPresentingAddItem) {
                AddItemView()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    now = .now
                }
            }
        }
    }

    private var itemList: some View {
        List {
            if !needsAttentionItems.isEmpty {
                Section("반품 마감 임박") {
                    ForEach(needsAttentionItems) { item in
                        ReturnItemRow(item: item, now: now)
                    }
                }
            }

            if !recentItems.isEmpty {
                Section("최근 등록") {
                    ForEach(recentItems) { item in
                        ReturnItemRow(item: item, now: now)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("아직 등록된 상품이 없습니다", systemImage: "shippingbox")
        } description: {
            Text("구매한 상품을 추가하면 반품 기한을 놓치지 않도록 정리해 드릴게요.")
        } actions: {
            Button("첫 상품 추가") {
                isPresentingAddItem = true
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: ReturnItem.self, inMemory: true)
}
