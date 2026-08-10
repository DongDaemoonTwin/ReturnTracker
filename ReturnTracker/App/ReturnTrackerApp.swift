import SwiftData
import SwiftUI

@main
struct ReturnTrackerApp: App {
    private let modelContainer: ModelContainer = {
        let schema = Schema([
            ReturnItem.self,
            ReturnStatusHistory.self
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: ScreenshotFixture.isEnabled
        )

        do {
            return try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
        } catch {
            fatalError("Unable to create SwiftData container: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
        .modelContainer(modelContainer)
    }
}
