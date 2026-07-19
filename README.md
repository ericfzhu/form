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

## Marketing site

The static product site lives at the repository root and uses Vite with Tailwind CSS.

```bash
yarn
yarn dev
```

Create a production build with `yarn build`. Cloudflare Pages should use:

- Build command: `yarn build`
- Build output directory: `dist`
- Node version: `22`

For a direct upload after authenticating Wrangler, run `yarn deploy`.
