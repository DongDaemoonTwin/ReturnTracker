# ReturnTracker

ReturnTracker is a local-first iPhone and Android app that remembers return deadlines and keeps purchased items in one place.

## Current vertical slice

- Native SwiftUI app for iOS 17+
- Local persistence with SwiftData
- Fast item creation flow
- Deadline-aware Home list sorted by urgency
- D-Day labels based on the user's current calendar and time zone
- Light/Dark Mode and Dynamic Type friendly system UI
- Native Android app with Kotlin, Jetpack Compose, Room, and Material 3

## Run on iOS

1. Open `ReturnTracker.xcodeproj` in Xcode 15 or later.
2. Select the `ReturnTracker` scheme and an iOS 17+ simulator or iPhone.
3. Press Run.

No API keys, server, or third-party packages are required.

## Run on Android

1. Open the `android` directory in Android Studio.
2. Install Android SDK 36 if Android Studio requests it.
3. Select the `app` configuration and an Android 6.0+ emulator or device.
4. Press Run.

From Linux or a Codespace with the Android SDK installed:

```bash
cd android
./gradlew testDebugUnitTest assembleDebug
```

The debug APK is written to `android/app/build/outputs/apk/debug/app-debug.apk`.

## Test

Run the iOS `ReturnTracker` scheme tests with **Product > Test** (`Command-U`). Android unit tests run with `./gradlew testDebugUnitTest`. Both suites cover deadline calculations for today, tomorrow, three days away, expired dates, refunded items, and formatted won input.

## Scope intentionally deferred

Item editing/deletion, status transitions and history, local notifications, OCR, widgets, StoreKit, and share extensions will be implemented in later phases after this first persistence flow is verified on a real device.
