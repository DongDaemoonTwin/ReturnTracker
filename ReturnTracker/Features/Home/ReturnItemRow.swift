import SwiftUI

struct ReturnItemRow: View {
    let item: ReturnItem
    let now: Date

    private var daysRemaining: Int {
        ReturnDeadline.daysRemaining(until: item.returnDeadline, now: now)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(item.productName)
                    .font(.headline)
                    .lineLimit(2)

                Text(item.storeName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Text(CurrencyFormatter.won(item.price))

                    Label(item.status.title, systemImage: item.status.symbolName)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if item.needsReview {
                    Text("메일 자동 등록 · 정보 확인 필요")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }

            Spacer(minLength: 8)

            Text(ReturnDeadline.label(until: item.returnDeadline, now: now))
                .font(daysRemaining > 0 ? .title3.weight(.semibold) : .subheadline.weight(.semibold))
                .foregroundStyle(deadlineColor)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: true, vertical: false)
                .accessibilityLabel("반품 기한 \(ReturnDeadline.label(until: item.returnDeadline, now: now))")
        }
        .padding(.vertical, 5)
    }

    private var deadlineColor: Color {
        switch daysRemaining {
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
}
