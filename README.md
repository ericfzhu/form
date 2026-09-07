# Form

Form is a minimal, offline-first iPhone workout log built with SwiftUI and SwiftData. It keeps the A/B/C training rotation, remembers previous sets, tracks progress, and preserves an active session when the app is closed.

## Requirements

- macOS with Xcode 16 or newer
- iOS 17 or newer
- An Apple Account for device signing and private CloudKit sync

## Run on an iPhone

1. Launch Xcode once and accept Apple's license agreement. Alternatively, run `sudo xcodebuild -license` in Terminal.
2. Open `Form.xcodeproj` in Xcode.
3. Select the **Form** target, then **Signing & Capabilities**.
4. Choose your Apple Account's Personal Team or developer team.
5. Ensure the iCloud container `iCloud.com.eric.form` is available to that team, or replace it with a container owned by the team.
6. Connect and select your iPhone as the run destination.
7. Press Run. If prompted, enable Developer Mode on the iPhone under **Settings → Privacy & Security → Developer Mode**.

## Storage and sync

Completed workouts are stored with SwiftData. Form opens a CloudKit-backed store using the user's private iCloud database when the configured container is available, and falls back to a local SwiftData store when it is not. There is no custom server or Form account.

The active workout is saved separately as a versioned, atomic local snapshot so it can be resumed safely. Workout history can also be exported to and restored from a JSON backup.

Apple Health synchronization is optional. Failed writes and deletions remain queued locally and can be retried after Health access is restored.

## Tests

The deterministic workout rules are exposed through a small Swift package. Run them locally with:

```bash
swift test
```

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

## Equipment-aware planner

The homepage is now a working local planner. It starts with the gym inventory Eric supplied, supports 2–4 sessions per week and 30/45/60-minute budgets, filters every exercise by equipment, supports movement swaps, and downloads a text plan. Changes stay in browser storage. The iOS app has **Plan**, **My gym**, and **Record** tabs; review the prefilled gym to begin. Gym settings are stored on-device and are not synced with the browser.

Both clients read `Form/Planning/exercises.json`. See `docs/PRODUCT_DIRECTION.md` for planning rules, assumptions, and compatibility decisions. Exercise demonstrations without artwork use a generic activity symbol. Active sessions embed their routine so later equipment changes do not alter work in progress.

Additional web planning tests: `node --test src/planner.test.js`. If the selected command-line Swift runtime is broken, use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test`.

This redesign is local-only; do not run deployment commands for it.
