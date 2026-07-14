# Form

Form is a minimal, offline-first iPhone workout log built with SwiftUI and SwiftData.

## Requirements

- macOS with Xcode 16 or newer
- iOS 17 or newer

## Run on an iPhone

1. Launch Xcode once and accept Apple's license agreement. Alternatively, run `sudo xcodebuild -license` in Terminal.
2. Open `Form.xcodeproj` in Xcode.
3. Select the **Form** target, then **Signing & Capabilities**.
4. Choose your Apple Account's Personal Team.
5. Connect and select your iPhone as the run destination.
6. Press Run. If prompted, enable Developer Mode on the iPhone under **Settings → Privacy & Security → Developer Mode**.

Workout history is stored locally on-device with SwiftData. No account or network connection is required.
