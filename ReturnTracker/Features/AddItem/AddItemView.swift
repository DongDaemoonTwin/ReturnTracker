import SwiftData
import SwiftUI

struct AddItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var productName = ""
    @State private var storeName = ""
    @State private var priceText = ""
    @State private var purchaseDate = Date.now
    @State private var returnDeadline = Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now
    @State private var orderNumber = ""
    @State private var note = ""
    @State private var saveErrorMessage: String?

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
                        .textInputAutocapitalization(.never)

                    TextField("구매처", text: $storeName)

                    TextField("구매 가격", text: $priceText)
                        .keyboardType(.numberPad)
                }

                Section("날짜") {
                    DatePicker(
                        "구매일",
                        selection: $purchaseDate,
                        displayedComponents: .date
                    )

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
            .navigationTitle("상품 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        save()
                    }
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

        let item = ReturnItem(
            productName: normalizedProductName,
            storeName: normalizedStoreName,
            price: price,
            purchaseDate: purchaseDate,
            returnDeadline: returnDeadline,
            orderNumber: orderNumber.nilIfBlank,
            note: note.nilIfBlank
        )

        modelContext.insert(item)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.delete(item)
            saveErrorMessage = error.localizedDescription
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

