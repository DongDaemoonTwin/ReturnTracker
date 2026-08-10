import SwiftData
import SwiftUI

struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var didPrepareFixture = false

    var body: some View {
        Group {
            if ScreenshotFixture.isEnabled {
                fixtureScreen
            } else {
                RootTabView()
            }
        }
        .task {
            guard ScreenshotFixture.isEnabled, !didPrepareFixture else { return }
            didPrepareFixture = true
            try? ScreenshotFixture.prepare(in: modelContext)
        }
    }

    @ViewBuilder
    private var fixtureScreen: some View {
        switch ScreenshotFixture.screen {
        case .home:
            RootTabView()
        case .add:
            AddItemView()
        case .detail:
            ScreenshotDetailView()
        }
    }
}

struct RootTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("홈", systemImage: "house")
                }

            ItemsView()
                .tabItem {
                    Label("전체 상품", systemImage: "shippingbox")
                }

            SettingsView()
                .tabItem {
                    Label("설정", systemImage: "gearshape")
                }
        }
    }
}

private struct ScreenshotDetailView: View {
    @Query(
        sort: [SortDescriptor(\ReturnItem.createdAt, order: .reverse)]
    ) private var items: [ReturnItem]

    var body: some View {
        NavigationStack {
            if let item = items.first {
                ItemDetailView(item: item)
            } else {
                ProgressView()
            }
        }
    }
}
