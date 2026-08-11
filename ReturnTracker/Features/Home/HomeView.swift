import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

    @Query(
        sort: [
            SortDescriptor(\ReturnItem.returnDeadline),
            SortDescriptor(\ReturnItem.createdAt, order: .reverse)
        ]
    ) private var items: [ReturnItem]

    @State private var isPresentingAddItem = false
    @State private var isSyncingGmail = false
    @State private var syncMessage: String?
    @State private var now = Date.now

    private var pendingItems: [ReturnItem] {
        items
            .filter { $0.status == .returnPlanned }
            .sorted { $0.returnDeadline < $1.returnDeadline }
    }

    private var needsAttentionItems: [ReturnItem] {
        items.filter {
            $0.status != .returnPlanned &&
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
                    item.status != .returnPlanned &&
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
                        syncGmail()
                    } label: {
                        if isSyncingGmail {
                            ProgressView()
                        } else {
                            Label("Gmail 동기화", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                    .disabled(isSyncingGmail)
                }

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
                "메일 동기화",
                isPresented: Binding(
                    get: { syncMessage != nil },
                    set: { if !$0 { syncMessage = nil } }
                )
            ) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(syncMessage ?? "")
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
            if !pendingItems.isEmpty {
                Section("반품 대기") {
                    ForEach(pendingItems) { item in
                        ReturnItemRow(item: item, now: now)
                    }
                }
            }

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
            Button("Gmail에서 동기화") {
                syncGmail()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSyncingGmail)

            Button("직접 추가") {
                isPresentingAddItem = true
            }
            .buttonStyle(.bordered)
        }
    }

    private func syncGmail() {
        guard !isSyncingGmail else { return }
        isSyncingGmail = true

        Task { @MainActor in
            defer { isSyncingGmail = false }
            do {
                let token = try await GmailOAuthClient().accessToken()
                let messages = try await GmailAPIClient().fetchRecentPurchaseEmails(accessToken: token)
                let candidates = messages.compactMap { PurchaseEmailParser.parse($0) }
                var importedItems: [ReturnItem] = []
                var knownMessageIDs = Set(items.compactMap(\.sourceMessageID))

                for candidate in candidates where !knownMessageIDs.contains(candidate.sourceMessageID) {
                    let item = ReturnItem(
                        productName: candidate.productName,
                        storeName: candidate.storeName,
                        price: candidate.price,
                        purchaseDate: candidate.purchaseDate,
                        returnDeadline: candidate.returnDeadline,
                        orderNumber: candidate.orderNumber,
                        note: candidate.note,
                        status: .returnPlanned,
                        source: .gmail,
                        sourceMessageID: candidate.sourceMessageID,
                        needsReview: candidate.needsReview
                    )
                    modelContext.insert(item)
                    importedItems.append(item)
                    knownMessageIDs.insert(candidate.sourceMessageID)
                }

                do {
                    try modelContext.save()
                } catch {
                    importedItems.forEach(modelContext.delete)
                    throw error
                }

                let skipped = candidates.count - importedItems.count
                syncMessage = switch (messages.count, candidates.count, importedItems.count, skipped) {
                case (0, _, _, _):
                    "최근 90일의 구매 메일을 찾지 못했습니다."
                case (_, 0, _, _):
                    "구매 정보로 판별할 수 있는 메일이 없습니다."
                case (_, _, let imported, let skipped) where skipped > 0:
                    "\(imported)개를 반품 대기에 추가하고, 이미 등록된 \(skipped)개는 건너뛰었습니다."
                case (_, _, let imported, _):
                    "\(imported)개를 반품 대기에 추가했습니다."
                }
            } catch {
                syncMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: ReturnItem.self, inMemory: true)
}
