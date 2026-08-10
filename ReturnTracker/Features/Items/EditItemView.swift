import SwiftData
import SwiftUI

struct EditItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true

    let item: ReturnItem

    @State private var productName: String
    @State private var storeName: String
    @State private var priceText: String
    @State private var purchaseDate: Date
    @State private var returnDeadline: Date
    @State private var orderNumber: String
    @State private var note: String
    @State private var saveErrorMessage: String?

    init(item: ReturnItem) {
        self.item = item
        _productName = State(initialValue: item.productName)
        _storeName = State(initialValue: item.storeName)
        _priceText = State(initialValue: NSDecimalNumber(decimal: item.price).stringValue)
        _purchaseDate = State(initialValue: item.purchaseDate)
        _returnDeadline = State(initialValue: item.returnDeadline)
        _orderNumber = State(initialValue: item.orderNumber ?? "")
        _note = State(initialValue: item.note ?? "")
    }

    private var normalizedProductName: String {
        productName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedStoreName: String {
        storeName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parsedPrice: Decimal? {
        CurrencyFormatter.decimal(from: priceText)
    }

    private var canSave: Bool {
        !normalizedProductName.isEmpty &&
            !normalizedStoreName.isEmpty &&
            parsedPrice != nil &&
            Calendar.current.startOfDay(for: returnDeadline) >= Calendar.current.startOfDay(for: purchaseDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("상품") {
                    TextField("상품명", text: $productName)
                    TextField("구매처", text: $storeName)
                    TextField("구매 가격", text: $priceText)
                        .keyboardType(.numberPad)
                }

                Section("날짜") {
                    DatePicker("구매일", selection: $purchaseDate, displayedComponents: .date)
                    DatePicker(
                        "반품 마감일",
                        selection: $returnDeadline,
                        in: Calendar.current.startOfDay(for: purchaseDate)...,
                        displayedComponents: .date
                    )
                }

                Section("선택 사항") {
                    TextField("주문번호", text: $orderNumber)
                    TextField("메모", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle("상품 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .onChange(of: purchaseDate) { _, newPurchaseDate in
                if returnDeadline < newPurchaseDate {
                    returnDeadline = Calendar.current.date(
                        byAdding: .day,
                        value: 14,
                        to: newPurchaseDate
                    ) ?? newPurchaseDate
                }
            }
            .alert(
                "저장할 수 없습니다",
                isPresented: Binding(
                    get: { saveErrorMessage != nil },
                    set: { if !$0 { saveErrorMessage = nil } }
                )
            ) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(saveErrorMessage ?? "알 수 없는 오류가 발생했습니다.")
            }
        }
    }

    private func save() {
        guard let price = parsedPrice, canSave else { return }

        item.productName = normalizedProductName
        item.storeName = normalizedStoreName
        item.price = price
        item.purchaseDate = purchaseDate
        item.returnDeadline = returnDeadline
        item.orderNumber = orderNumber.nilIfBlankForEdit
        item.note = note.nilIfBlankForEdit
        item.updatedAt = .now

        do {
            try modelContext.save()
            updateNotifications()
            dismiss()
        } catch {
            modelContext.rollback()
            saveErrorMessage = error.localizedDescription
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

private extension String {
    var nilIfBlankForEdit: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
