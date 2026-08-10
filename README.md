# ReturnTracker

ReturnTracker is a local-first iPhone app that remembers return deadlines and keeps purchased items in one place.

## Current MVP flow

- Native SwiftUI app for iOS 17+
- Local persistence with SwiftData
- Fast item creation flow
- Deadline-aware Home list sorted by urgency
- D-Day labels based on the user's current calendar and time zone
- Item detail, editing, deletion, and searchable all-items list
- Six return/refund states with status history
- Local D-3, D-1, and deadline-day notifications
- Home sections for urgent deadlines and pending refunds
- Light/Dark Mode and Dynamic Type friendly system UI

## Run

1. Open `ReturnTracker.xcodeproj` in Xcode 26 or later.
2. Select the `ReturnTracker` scheme and an iOS 17+ simulator or iPhone.
3. Press Run.

No API keys, server, or third-party packages are required.

## Test

Run the `ReturnTracker` scheme tests with **Product > Test** (`Command-U`). The suite covers deadline calculations, post-shipment attention rules, formatted prices, and local-notification dates in Asia/Seoul.

Every push to `main` or `agent/**` also runs the same tests on GitHub Actions using macOS 26 and Xcode 26.6. The workflow uploads screenshots for the empty Home, populated Home, item creation, item detail, and Dark Mode screens.

## Scope intentionally deferred

Photos/OCR, widgets, StoreKit, share extensions, and signed TestFlight delivery remain outside the current MVP. TestFlight requires an Apple Developer membership and App Store Connect signing credentials.
