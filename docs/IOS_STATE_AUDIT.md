# iOS state and action audit

Reviewed 25 October 2026. This is a source review plus targeted regression testing, not a claim that every possible interaction has been verified on a device.

## Transition contract

| State / action | Success | Cancel / failure | Evidence |
| --- | --- | --- | --- |
| Today: start or resume | Load current snapshot before presenting logger | Unreadable/newer/unknown-routine snapshot shows recovery information; starting is blocked | Code review; persistence tests |
| Restore missing snapshot | Offer a new session | Missing file is distinct from a read/decode failure | Persistence tests |
| Restore damaged/newer snapshot | Retry or explicitly discard | Original bytes remain intact; autosave cannot overwrite them | Persistence tests |
| Legacy snapshot migration | Write new file before removing legacy entry | Keep legacy entry if migration fails | Filesystem-failure regression test |
| Log sets in any order | Set stays in place; rest is nonblocking | Completion can be toggled off | Workflow tests; simulator logged third movement before completing earlier ones |
| Reorder / resume | Preserve exercise order and recorded sets | No reset of existing progress | Existing workflow tests |
| Pause and close | Persist paused state before dismissal | Failed write resumes session and walk; logger stays open with dismissible error | Transition tests; installed-app read-only-directory check and successful retry |
| Finish request | Decide empty, partial, or complete without mutating workout | Cancel leaves walk running | New transition tests |
| Confirm Finish | Stop timers, include walk once, save history, clear active snapshot | Failed history save restores walk/cardio and resumes; retry does not duplicate walk | New transition tests |
| Finish partial session | Save completed work | Keep training cancels; save action is not styled as destructive | Simulator saved two sets and one walk; Today no longer offered the finished session |
| Discard active session | Clear snapshot before dismissal | Clear failure keeps session open; error is shown | Code review |
| Delete saved workout | Explicit confirmation, then local delete and Health deletion request | Cancel preserves record; failed local save rolls back | Simulator confirmation/cancel; local rollback source review; Health queue delete/retry tests; destructive UI commit not exercised |
| Edit saved workout | Save changes before dismissal | Cancel checks unsaved edits; failed save retains drafts and original saved values | Simulator successful edit; repeated failure/retry and orphan-record regression tests |
| Rest deadline / adjustment / skip | Shared deadline supports foreground and Live Activity state | Notification denial does not block logging | Timer tests; simulator notification denial and relaunch after expiry |
| Background / foreground | Save active snapshot, update Live Activity on return | Running duration, walk, and rest anchors survive relaunch | Serialization regression test; simulator termination/relaunch and lock/unlock |
| Live Activity link | Validate URL and matching session, then resume | Stale link ignored; unreadable snapshot gives recovery error | Existing URL tests; routing reviewed |
| History / progress / routine navigation | Back and tab navigation; content reserves tab space | Adaptive layouts and descriptive input labels | Largest-text History, routine sheet, progress, and editor bottom content reached with accessibility scroll actions; Inspector traversal checked; physical VoiceOver remains |
| Health sync | Optional sync with durable queued jobs; refresh retries pending work | Queue read/write errors preserve data and surface errors | Queue deduplication, supersession, corrupt/newer files, and actual filesystem-failure tests; simulator connection-error state |
| Storage | Workouts stored locally; backups support transfer | Settings accurately explain local storage | Source review: current model configuration explicitly disables CloudKit |
| Backup import/export | Restore valid records once | Cancel silently; reject malformed/newer/invalid measurements; failed save rolls back | Picker cancellation on simulator; roundtrip, duplicate, invalid-file, repeated-failure/retry tests |

## Changes in this pass

- Pause persistence and finalization now have testable state transitions with rollback on failure.
- Finish confirmation no longer ends a walk before the user decides.
- History deletion requires confirmation from swipe and context-menu paths; full-swipe deletion is disabled.
- Active snapshot recovery reports errors and guards against overwriting damaged/newer data. Today offers retry and confirmed discard; other launch paths report the problem.
- Discard checks storage deletion before dismissing. Legacy migration only removes its source after writing successfully.
- First-history prefill runs once per logger instance, so a subsequent appearance cannot overwrite edits.
- Set inputs identify exercise, set, and measurement to accessibility clients.
- Running snapshots use stable timer anchors. A failed autosave no longer creates an endless alert loop as elapsed time changes.
- Backup restores validate measurements and roll back failed inserts; cancelling the file picker is silent.
- Saved-workout edits restore original values and relationships after failed writes, while keeping editable drafts available for retry.
- Health queue mutations reach disk before replacing the cached queue. Damaged or newer queue files are preserved; superseded jobs cannot overwrite newer jobs.
- Returning to the app refreshes Health status and pending work; the Settings refresh action also retries pending records.
- Large-text layouts adapt workout fields, timer controls, editor fields, headers, history dates, and tab labels. Warm-up-only exercises remain visible in History.
- Storage copy now describes the actual local-only configuration instead of suggesting iCloud will become available automatically.
- History uses one explicit navigation path for workout and exercise destinations. This fixes exercise progress immediately returning to the workout when opened from History.
- Accessibility-size editor date and time controls occupy separate rows; the cardio type selector has a fully wrapping custom label and no longer overlaps its measurements.
- Progress filters use two columns at accessibility sizes; overview, statistics, and session summaries wrap vertically instead of truncating. Selected period/metric controls expose their selected state.
- Screen/section headings expose header traits. Editor remove/add/set-type controls include exercise and set context; set types expose their values. Cardio fields and delete actions identify the activity. Related statistics and form cues are grouped for reading.

## Validation completed

61 tests passed (42 XCTest and 19 Swift Testing), and the iOS Simulator Debug build succeeded. This pass used an isolated iPhone SE (3rd generation) simulator named **Form State Audit**, running iOS 26.5, with generated test workouts. The existing review simulator and its data were left alone.

- Completed sets out of order, saved a partial workout with a timed walk exactly once, and verified Today advanced instead of offering the finished session.
- Terminated/relaunched during rest and walking; preserved recorded work and timer anchors. Lock/unlock preserved the walk, and its Live Activity appeared on the lock screen.
- Denied notifications without blocking logging. Health connection failure displayed an error without blocking the app.
- Induced an installed-app write failure with a read-only session directory, reproduced and fixed the repeated-alert loop, dismissed the error, restored directory permissions, and saved successfully. Unit tests also use real filesystem write/delete failures and failed legacy migration.
- Checked History deletion confirmation/cancellation, successful saved-workout editing, and backup-picker cancellation.
- Verified the normal-size History detail's final cardio content clears the bottom tabs on the small screen.
- At the largest accessibility text size, verified History date/header/tab layouts and workout input labels, timer controls, numeric keyboard, Next-field navigation, Done dismissal, and Pause and close.

### Scrolling and accessibility follow-up

The follow-up build and all 61 regression tests passed. On the same iPhone SE simulator at the largest accessibility text size, Accessibility Inspector's native **Scroll down / Scroll up** actions provided reliable scrolling where the computer-control tool's drag gestures had not.

| Screen | Observed result |
| --- | --- |
| History detail | Final `TIME, 1.63 min` content fully above the Today/History tabs |
| Routine sheet opened from Today | Last reverse-lunge prescription and final 15-minute treadmill note fully reachable |
| Exercise progress opened from History | Screen stays open; final baseline summary and explanatory text fully above tabs; period labels and full performance summary readable after fixes |
| Saved-workout editor | Final incline field and `Add another cardio entry` reachable; date/time and cardio selector readable after fixes |

Inspector traversal verified separate Today and History buttons with the selected trait, screen headings, workout exercise links, editor Cancel/Save, exercise headings, contextual set controls and field values. The cardio menu exposes its current value and selected option. Related progress statistics now read as label/value pairs instead of disconnected columns. This is accessibility-inspection evidence, not a physical VoiceOver pass.

The initial automated Inspector audit reported nine Dynamic Type warnings on Today. Text was observed scaling in the app; those audit warnings were not treated as proof of failure or a clean audit. Follow-up testing targeted actual clipping, element semantics, and reachability.

## Remaining device verification

- Actual VoiceOver spoken traversal, rotor navigation, and focus after presentation/dismissal on a physical iPhone. Apple states that VoiceOver is unavailable in Simulator; Inspector checks do not replace it. See [Performing accessibility testing for your app](https://developer.apple.com/documentation/accessibility/performing-accessibility-testing-for-your-app).
- Physical touch scrolling, including VoiceOver three-finger scrolling. Simulator accessibility scroll actions reached the bottom of History, editor, routine sheet, and progress at the largest text size. The multi-session chart/history branch and legacy routine-detail route were reviewed in source but not exercised with populated UI fixtures in this pass.
- Signed-device Health authorization denied/granted flows, HealthKit save/delete delivery and retry after permission changes. The unsigned simulator returned a connection error before an authorization sheet; queue persistence tests do not establish end-to-end HealthKit behavior.
- Backup export/share destination and successful import through Files. Serialization, restore behavior, and picker cancellation are covered, but the complete system share/Files roundtrip remains manual.
- Confirmed History deletion through the UI, including local database-save failure. This pass verified the confirmation and cancellation paths, and separately tested queued Health deletion persistence.
- Physical-device lock-screen Live Activity routing and notification delivery. Simulator lock/relaunch and URL-routing tests cover only part of those integrations.

Disconnected iCloud is not an applicable runtime state in this build: `AppModelContainer` currently uses `cloudKitDatabase: .none`. No iCloud sync is claimed.

### Physical VoiceOver acceptance sequence

1. With VoiceOver enabled, swipe through Today; confirm Resume/Start and both tabs are reachable, and the selected tab is announced.
2. Open History, a workout, then an exercise. Confirm each screen title, Back, and Edit are reachable, and Back returns one level. Use the headings rotor on progress and three-finger scroll to the final content.
3. Open Edit. Navigate date/time, set-type pickers, load/repetition fields, remove/add controls, and cardio fields. Confirm exercise/set context and current values are spoken; edit a test value, dismiss the keyboard, and check Cancel/Save focus.
4. Resume a test workout, complete and uncomplete a set, adjust/skip rest, then open and cancel Finish. Check focus returns to the relevant control and the timer does not repeatedly interrupt speech. Pause and resume, confirming recorded values remain intact.

Apple guidance used as the review baseline: [Alerts](https://developer.apple.com/design/human-interface-guidelines/alerts), [Undo and redo](https://developer.apple.com/design/human-interface-guidelines/undo-and-redo), and [Writing](https://developer.apple.com/design/human-interface-guidelines/writing).
