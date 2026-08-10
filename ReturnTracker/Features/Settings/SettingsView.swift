import SwiftData
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @Query private var items: [ReturnItem]

    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("반품 마감 알림", isOn: $notificationsEnabled)

                    LabeledContent("시스템 권한", value: authorizationTitle)

                    Button("알림 권한 다시 확인") {
                        Task {
                            await requestAndSchedule()
                        }
                    }
                } header: {
                    Text("알림")
                } footer: {
                    Text("허용하면 반품 마감 D-3, D-1, 당일 오전 9시에 알려드립니다. 권한이 거절된 경우 iPhone 설정에서 변경할 수 있습니다.")
                }

                Section("데이터") {
                    LabeledContent("저장된 상품", value: "\(items.count)개")
                    Text("모든 정보는 이 iPhone의 SwiftData 저장소에만 보관됩니다.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("앱 정보") {
                    LabeledContent("버전", value: "0.2.0")
                    LabeledContent("최소 iOS", value: "iOS 17")
                }
            }
            .navigationTitle("설정")
            .task {
                await refreshAuthorizationStatus()
            }
            .onChange(of: notificationsEnabled) { _, isEnabled in
                if isEnabled {
                    Task {
                        await requestAndSchedule()
                    }
                } else {
                    NotificationService.shared.cancelAll()
                }
            }
        }
    }

    private var authorizationTitle: String {
        switch authorizationStatus {
        case .notDetermined:
            "아직 요청하지 않음"
        case .denied:
            "허용 안 함"
        case .authorized:
            "허용됨"
        case .provisional:
            "잠정 허용"
        case .ephemeral:
            "임시 허용"
        @unknown default:
            "확인 필요"
        }
    }

    private func refreshAuthorizationStatus() async {
        authorizationStatus = await NotificationService.shared.authorizationStatus()
    }

    private func requestAndSchedule() async {
        let granted = await NotificationService.shared.requestAuthorization()
        await refreshAuthorizationStatus()

        guard granted else {
            notificationsEnabled = false
            return
        }

        for item in items {
            await NotificationService.shared.schedule(for: item)
        }
    }
}
