import SwiftData
import SwiftUI

struct ItemDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true

    @Bindable var item: ReturnItem
    @Query(
        sort: [SortDescriptor(\ReturnStatusHistory.changedAt, order: .reverse)]
    ) private var histories: [ReturnStatusHistory]

    @State private var isPresentingEdit = false
    @State private var isConfirmingDelete = false
    @State private var errorMessage: String?

    private var itemHistories: [ReturnStatusHistory] {
        histories.filter { $0.itemID == item.id }
    }

    var body: some View {
        List {
            deadlineSection
            statusSection
            purchaseSection

            if item.orderNumber != nil || item.note != nil {
                optionalDetailsSection
            }

            if !itemHistories.isEmpty {
                historySection
            }
        }
        .navigationTitle(item.productName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("수정") {
                    isPresentingEdit = true
                }
            }
        }
        .sheet(isPresented: $isPresentingEdit) {
            EditItemView(item: item)
        }
        .safeAreaInset(edge: .bottom) {
            deleteButton
        }
        .confirmationDialog(
            "이 상품을 삭제할까요?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("상품 삭제", role: .destructive) {
                deleteItem()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("저장된 상품 정보와 상태 기록이 함께 삭제됩니다.")
        }
        .alert(
            "변경사항을 저장할 수 없습니다",
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

    private var deadlineSection: some View {
        Section {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("반품 마감")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(item.returnDeadline, format: .dateTime.year().month().day())
                        .font(.body)
                }

                Spacer()

                Text(ReturnDeadline.label(until: item.returnDeadline))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(deadlineColor)
            }
            .padding(.vertical, 6)
        }
    }

    private var statusSection: some View {
        Section("현재 상태") {
            Menu {
                ForEach(ReturnStatus.allCases) { status in
                    Button {
                        changeStatus(to: status)
                    } label: {
                        Label(status.title, systemImage: status == item.status ? "checkmark" : status.symbolName)
                    }
                }
            } label: {
                HStack {
                    Label(item.status.title, systemImage: item.status.symbolName)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
        }
    }

    private var purchaseSection: some View {
        Section("구매 정보") {
            LabeledContent("구매처", value: item.storeName)
            LabeledContent("구매 가격", value: CurrencyFormatter.won(item.price))
            LabeledContent("구매일") {
                Text(item.purchaseDate, format: .dateTime.year().month().day())
            }
        }
    }

    private var optionalDetailsSection: some View {
        Section("추가 정보") {
            if let orderNumber = item.orderNumber {
                LabeledContent("주문번호", value: orderNumber)
            }

            if let note = item.note {
                VStack(alignment: .leading, spacing: 6) {
                    Text("메모")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(note)
                }
            }
        }
    }

    private var historySection: some View {
        Section("상태 기록") {
            ForEach(itemHistories.prefix(5)) { history in
                HStack {
                    Label(history.status.title, systemImage: history.status.symbolName)
                    Spacer()
                    Text(history.changedAt, format: .dateTime.month().day().hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            isConfirmingDelete = true
        } label: {
            Label("상품 삭제", systemImage: "trash")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .padding()
        .background(.bar)
    }

    private var deadlineColor: Color {
        switch ReturnDeadline.daysRemaining(until: item.returnDeadline) {
        case ..<0:
            .secondary
        case 0...1:
            .red
        case 2...3:
            .orange
        default:
            .primary
        }
    }

    private func changeStatus(to newStatus: ReturnStatus) {
        let previousStatus = item.status
        guard previousStatus != newStatus else { return }

        let history = ReturnStatusHistory(itemID: item.id, status: newStatus)
        item.status = newStatus
        modelContext.insert(history)

        do {
            try modelContext.save()
            updateNotifications()
        } catch {
            item.status = previousStatus
            modelContext.delete(history)
            errorMessage = error.localizedDescription
        }
    }

    private func deleteItem() {
        let itemID = item.id

        do {
            itemHistories.forEach { modelContext.delete($0) }
            modelContext.delete(item)
            try modelContext.save()
            NotificationService.shared.cancel(itemID: itemID)
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func updateNotifications() {
        guard notificationsEnabled else {
            NotificationService.shared.cancel(itemID: item.id)
            return
        }

        Task {
            await NotificationService.shared.schedule(for: item)
        }
    }
}
