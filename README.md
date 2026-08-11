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
- User-triggered Gmail purchase-email synchronization on iOS and Android
- Automatic duplicate protection and a dedicated `반품 대기` list
- Manual item creation remains available without connecting an email account

## Gmail synchronization

When the user taps the sync button, ReturnTracker requests read-only Gmail access, searches up to 30 recent order/receipt messages from the last 90 days, and extracts the product, store, price, order number, purchase date, and return deadline. Imported items are stored only on the device and start in the `반품 예정` state.

If a message does not contain a clear return deadline, the app temporarily estimates 14 days from the purchase-email date and marks the item as `정보 확인 필요`. The Gmail message ID is stored with the item so a later sync does not create a duplicate. Email contents and OAuth access tokens are not sent to a ReturnTracker server.

Before live Gmail sync can be used:

1. Create a Google Cloud project, enable the Gmail API, and configure the OAuth consent screen.
2. Request the restricted `gmail.readonly` scope. Public distribution requires Google's OAuth verification.
3. For Android, register an Android OAuth client for package `com.returntracker.android` with the signing certificate SHA-1.
4. For iOS, register an iOS OAuth client for bundle ID `com.dongdaemoontwin.ReturnTracker`, then replace `REPLACE_ME` in `ReturnTracker/Resources/Info.plist` with the client ID and its reversed-client-ID URL scheme.

The app still builds when these production credentials are absent. Android authorization will only succeed for a package/signing identity registered in Google Cloud; iOS shows a configuration message until the placeholder values are replaced.

## Run on iOS

1. Open `ReturnTracker.xcodeproj` in Xcode 15 or later.
2. Select the `ReturnTracker` scheme and an iOS 17+ simulator or iPhone.
3. Press Run.

No ReturnTracker server is required. Gmail sync requires the OAuth setup above.

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
Successful Android GitHub Actions runs also provide it as the `ReturnTracker-debug-apk` artifact.

## Test

Run the iOS `ReturnTracker` scheme tests with **Product > Test** (`Command-U`). Android unit tests run with `./gradlew testDebugUnitTest`. Both suites cover deadline calculations for today, tomorrow, three days away, expired dates, refunded items, and formatted won input.

## Scope intentionally deferred

Item editing/deletion, status transitions and history, local notifications, advanced merchant-specific parsers, Outlook support, OCR, widgets, StoreKit, and share extensions will be implemented in later phases.
