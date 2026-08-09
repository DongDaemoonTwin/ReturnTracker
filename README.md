# ReturnTracker

ReturnTracker is a local-first iPhone app that remembers return deadlines and keeps purchased items in one place.

## Current vertical slice

- Native SwiftUI app for iOS 17+
- Local persistence with SwiftData
- Fast item creation flow
- Deadline-aware Home list sorted by urgency
- D-Day labels based on the user's current calendar and time zone
- Light/Dark Mode and Dynamic Type friendly system UI

## Run

1. Open `ReturnTracker.xcodeproj` in Xcode 15 or later.
2. Select the `ReturnTracker` scheme and an iOS 17+ simulator or iPhone.
3. Press Run.

No API keys, server, or third-party packages are required.

## Test

Run the `ReturnTracker` scheme tests with **Product > Test** (`Command-U`). The first test suite covers deadline calculations for today, tomorrow, three days away, expired dates, and dates spanning midnight in Asia/Seoul.

## Scope intentionally deferred

Item editing/deletion, status transitions and history, local notifications, OCR, widgets, StoreKit, and share extensions will be implemented in later phases after this first persistence flow is verified on a real device.

