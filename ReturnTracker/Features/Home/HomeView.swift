import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true

    @Query(
        sort: [
            SortDescriptor(\ReturnItem.returnDeadline),
            SortDescriptor(\ReturnItem.createdAt, order: .reverse)
        ]
    ) private var items: [ReturnItem]

    @Query(
        sort: [SortDescriptor(\ReturnStatusHistory.changedAt, order: .reverse)]
    ) private var histories: [ReturnStatusHistory]

    @State private var isPresentingAddItem = false
    @State private var now = Date.now
    @State private var errorMessage: String?

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
                    !needsAttentionItems.contains { $0.id == item.id } &&
                        item.status != .refundPending
                }
                .prefix(5)
        )
    }

    private var refundPendingItems: [ReturnItem] {
        items.filter { $0.status == .refundPending }
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
            .alert(
                "상태를 변경할 수 없습니다",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "알 수 없는 오류가 발생했습니다.")
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
                        NavigationLink {
                            ItemDetailView(item: item)
                        } label: {
                            ReturnItemRow(item: item, now: now)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("반품 예정") {
                                changeStatus(item, to: .returnPlanned)
                            }
                            .tint(.orange)
                        }
                    }
                }
            }

            if !refundPendingItems.isEmpty {
                Section("환불 대기") {
                    ForEach(refundPendingItems) { item in
                        NavigationLink {
                            ItemDetailView(item: item)
                        } label: {
                            RefundPendingRow(
                                item: item,
                                shippedAt: shippedDate(for: item),
                                now: now
                            )
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button("환불 완료") {
                                changeStatus(item, to: .refunded)
                            }
                            .tint(.green)
                        }
                    }
                }
            }

            if !recentItems.isEmpty {
                Section("최근 등록") {
                    ForEach(recentItems) { item in
                        NavigationLink {
                            ItemDetailView(item: item)
                        } label: {
                            ReturnItemRow(item: item, now: now)
                        }
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

    private func shippedDate(for item: ReturnItem) -> Date? {
        histories.first {
            $0.itemID == item.id && $0.status == .shipped
        }?.changedAt
    }

    private func changeStatus(_ item: ReturnItem, to newStatus: ReturnStatus) {
        let previousStatus = item.status
        guard previousStatus != newStatus else { return }

        let history = ReturnStatusHistory(itemID: item.id, status: newStatus)
        item.status = newStatus
        modelContext.insert(history)

        do {
            try modelContext.save()
            updateNotifications(for: item)
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func updateNotifications(for item: ReturnItem) {
        guard notificationsEnabled else {
            NotificationService.shared.cancel(itemID: item.id)
            return
        }

        Task {
            await NotificationService.shared.schedule(for: item)
        }
    }
}

private struct RefundPendingRow: View {
    let item: ReturnItem
    let shippedAt: Date?
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.productName)
                    .font(.headline)
                    .lineLimit(2)
                Spacer()
                Label("환불 대기", systemImage: "clock.arrow.circlepath")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }

            Text(item.storeName)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Text(CurrencyFormatter.won(item.price))
                Spacer()
                Text(elapsedLabel)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 5)
    }

    private var elapsedLabel: String {
        guard let shippedAt else { return "환불 입금 확인 필요" }
        let start = Calendar.autoupdatingCurrent.startOfDay(for: shippedAt)
        let end = Calendar.autoupdatingCurrent.startOfDay(for: now)
        let days = max(
            0,
            Calendar.autoupdatingCurrent.dateComponents([.day], from: start, to: end).day ?? 0
        )
        return "반품 발송 \(days)일 경과"
    }
}

#Preview {
    HomeView()
        .modelContainer(
            for: [ReturnItem.self, ReturnStatusHistory.self],
            inMemory: true
        )
}
