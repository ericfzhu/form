# iOS state and action audit

Reviewed 25–26 October 2026. This is a source review plus targeted regression testing, not a claim that every possible interaction has been verified on a device.

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
| Delete saved workout | Explicit confirmation, then local delete and Health deletion request | Cancel preserves record; failed local save rolls back | Simulator confirmed deletion and Files restoration; repeated injected save-error, retry and child-record regression test; Health queue delete/retry tests; installed-store failure limitation below |
| Edit saved workout | Save changes before dismissal | Cancel checks unsaved edits; failed save retains drafts and original saved values | Simulator successful edit; repeated failure/retry and orphan-record regression tests |
| Rest deadline / adjustment / skip | Shared deadline supports foreground and Live Activity state | Notification denial does not block logging | Timer tests; simulator notification denial and relaunch after expiry |
| Background / foreground | Save active snapshot, update Live Activity on return | Running duration, walk, and rest anchors survive relaunch | Serialization regression test; simulator termination/relaunch and lock/unlock |
| Live Activity link | Validate URL and matching session, then resume | Stale link ignored; unreadable snapshot gives recovery error | Existing URL tests; routing reviewed |
| History / progress / routine navigation | Back and tab navigation; content reserves tab space | Adaptive layouts and descriptive input labels | Largest-text History, routine sheet, populated progress, and editor bottom content reached with accessibility actions; Inspector traversal checked; physical VoiceOver skipped by request |
| Health sync | Optional sync with durable queued jobs; refresh retries pending work | Queue read/write errors preserve data and surface errors | Queue deduplication, supersession, corrupt/newer files, and actual filesystem-failure tests; simulator connection-error state |
| Storage | Workouts stored locally; backups support transfer | Settings accurately explain local storage | Source review: current model configuration explicitly disables CloudKit |
| Backup import/export | Restore valid records once | Cancel silently; reject malformed/newer/invalid measurements; failed save rolls back | Simulator export to Files, duplicate import and four-session import; roundtrip, invalid-file, oversized-number and repeated-failure/retry tests |

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

### Field editing and validation follow-up

The field pass preserves the existing ink, paper, script typography and underlined inputs. It adds a shared raw-text editing layer so incomplete or invalid input stays editable instead of silently retaining an old number. Errors appear after leaving a field or trying to complete/save; they identify the correction beside the field and in its accessibility hint. Complete set, Finish, Pause and close, and editor Save validate before proceeding. The persistence layer also rejects invalid measurements before changing saved records.

| Field | Editing and validation behavior |
| --- | --- |
| Set weight | Decimal keyboard; nonnegative finite numbers; blank or malformed values require correction; zero remains valid for unloaded work |
| Repetitions / timed-set seconds | Number keyboard; nonnegative whole numbers; fractional and malformed pasted values rejected |
| Session duration / cardio minutes | Positive decimal minutes; sub-minute values accepted without silently raising them to one minute |
| Cardio distance, speed, incline | Explicit optional guidance; blank means zero/unrecorded; negative or malformed values rejected; unsupported incline removed from validation and focus order |
| Session title | Explicit optional label, sentence capitalization and ordered Next navigation; blank retains the routine-name fallback |
| Gym name | Explicit optional label, word capitalization and Done dismissal; trimmed blank uses “My gym” (source review of the legacy planner form) |
| Exercise search | Descriptive prompt, Clear search, Search return key, whitespace-tolerant matching and a no-results message |
| Date and time | Existing native pickers retained, including separate rows at accessibility text sizes |

Previous/Next/Done navigation covers both set and cardio entries and the saved-workout editor. Focus requests scroll after keyboard layout, with duration/cardio captions included in the target. Invalid raw entries survive moving between fields while the form is open. Automatic session snapshots persist the last valid numeric values; invalid raw text is not restored after process termination.

Focusing a rounded display no longer writes that presentation back over a more precise saved measurement. The editor retains its original comparison baseline across view recreation, avoiding false unsaved-change prompts. Warm-up field labels now identify the warm-up and number it from one.

Validation: **69 tests passed** (50 XCTest and 19 Swift Testing), and the iOS Simulator Debug build succeeded. New tests cover strict parsing, decimal-comma locales, Unicode digits, unsafe pasted values, required/optional measurements, raw draft retention, precision preservation on focus, external model changes, removed fields, and rejection before repository mutation.

On the isolated iPhone SE audit simulator, verified:

- Cleared weight prevents set completion; malformed `12kg` stays intact across Next navigation and prevents Finish; correction clears the error.
- Focused fields and inline errors remain above the rest bar and software keyboard.
- Zero session duration blocks Save with specific inline guidance; correcting and saving with the keyboard still open persists the new value on reopening.
- A blank optional cardio distance saves successfully.
- Focusing an unchanged precise duration (displayed as `12.56`, stored as `12.5555`) then cancelling closes without a discard prompt.
- At the largest accessibility text size, the complete duration caption, value and error remain visible above the keyboard. Correcting back to the original value then cancelling also closes without a false prompt.
- Search displays a no-results message and Clear restores the exercise list.

The simulator was returned to its original standard text size. Physical-iPhone testing is excluded from this audit at the user's request. Simulator and automated results remain the verification evidence; skipped device checks are not counted as passed.

## Physical-iPhone checks skipped by request

These checks are out of scope and do not block completion of this audit.

- Actual VoiceOver spoken traversal, rotor navigation, and focus after presentation/dismissal on a physical iPhone. Apple states that VoiceOver is unavailable in Simulator; Inspector checks do not replace it. See [Performing accessibility testing for your app](https://developer.apple.com/documentation/accessibility/performing-accessibility-testing-for-your-app).
- Physical touch scrolling, including VoiceOver three-finger scrolling. Simulator accessibility scroll actions reached the bottom of History, editor, routine sheet, and progress at the largest text size.
- Signed-device Health authorization denied/granted flows, HealthKit save/delete delivery and retry after permission changes. The unsigned simulator returned a connection error before an authorization sheet; queue persistence tests do not establish end-to-end HealthKit behavior.
- Physical-device lock-screen Live Activity routing and notification delivery. Simulator lock/relaunch and URL-routing tests cover only part of those integrations.

## Remaining simulator checks: 26 October follow-up

**71 tests passed** (52 XCTest and 19 Swift Testing), and the final iOS Simulator Debug build succeeded. Installed and launched that build; History retained all five synthetic sessions and displayed the corrected singular movement labels. The isolated audit simulator and synthetic records were used throughout.

- Exported the original synthetic workout using the system share sheet's Save to Files destination. Restoring that JSON through Files reported no new sessions, without duplicates. Importing `Tests/Fixtures/history-audit.json` through Files restored four sessions.
- Added Export a backup beside Restore a backup in History options, keeping the existing overview export entry.
- Verified populated exercise progress: 12 weeks includes four sessions; All time includes the older fifth session; switching Load to Volume changes the chart and selected state. The last July session clears the bottom tabs at standard and maximum accessibility text sizes. Returned the simulator to standard text size afterward.
- Found and fixed a SwiftData cascade-deletion rollback crash involving unfaulted child records. Deletion now materializes the complete workout graph before mutation. A regression test injects two failed saves, verifies children and unrelated workouts survive, then retries successfully without orphan records. Health deletion is queued only after the local save succeeds.
- Backup imports now reject oversized numeric values before history formatting can overflow an integer. Legacy zero durations remain supported; import bounds match the editing rules. Regression coverage rejects oversized duration, load and repetition values before inserting records.
- Corrected singular session/movement labels and README storage instructions to match the local-only configuration.
- The legacy `RoutineDetailView` is not reachable through current production Today navigation: Today opens the routine sheet. Its old navigation callers remain in dormant planner/list views. It is source-reviewed, not counted as a tested reachable screen.

With the user's confirmation, deleted the synthetic “Audit delete and restore” session through History. The count changed from five to four and the other four sessions remained. Restoring the fixture through Files reported “Restored 1 session,” returned the count to five, and preserved both 35 kg × 8 sets and the 10-minute walk with 0.8 km, 4.8 km/h and 2% incline.

Installed-store failure limitation: a temporary SQLite trigger targeted only that synthetic record and aborted its deletion. Core Data terminated inside `NSManagedObjectContext.save` (`_thereIsNoSadnessLikeTheDeathOfOptimism`) before returning a catchable Swift error, so this method did not verify the app's error presentation. The trigger was removed and its absence checked; all five records survived the failed transaction. The normal UI deletion/restoration above then succeeded. Recoverable save-error handling remains covered by automated error injection and rollback/retry tests, not an installed-app storage-failure UI pass. No test trigger or database schema modification remains.

Disconnected iCloud is not an applicable runtime state in this build: `AppModelContainer` currently uses `cloudKitDatabase: .none`. No iCloud sync is claimed.

### Visual direction

The user confirmed amo (Bump, ID and Capture) as the personality reference. Apple's guidance remains the interaction and accessibility baseline, without prescribing the visual aesthetic. Preserve Form's ink, paper, script typography and underlined fields.

### Set completion and rest personality pass

- Set completion draws a custom ink check into a slightly tilted stamp, gives a brief spring response and one medium-impact haptic, and leaves a subtle blue wash on the completed row. Validation still runs first. Undoing completion is immediate; loading saved completed sets does not trigger the haptic.
- Rest enters as a paper note with the existing seated character, handwritten heading and quiet blue tint. The character gives a brief settling motion when another set starts rest. There is no continuous decorative animation, motivational-message rotation or delay before the next action.
- Existing rest preferences, warm-up timing, deadline persistence and Skip/adjust/Done behavior remain intact. The note becomes compact while editing with the keyboard; accessibility sizes use a shorter heading and stacked controls. Completion buttons expose both their action and current value.
- Reduce Motion branches remove check drawing, stamp scaling, character movement and the sliding footer transition (source-reviewed; the simulator's Reduce Motion setting was left unchanged). Physical haptic feel and VoiceOver speech remain excluded from this pass at the user's request.

Validation: 71 existing tests passed and the final simulator build succeeded. On the isolated iPhone SE simulator, checked complete/undo/re-complete, restarting an existing rest deadline, keyboard clearance, maximum text size, and subtracting time through Ready then dismissing the note. Verified the final shorter accessibility heading and returned to standard text size. No additional implementation-mirroring tests were added for this visual change.

### Finishing and completion personality pass

- A successful save triggers a single success haptic and a brief fade into the completion screen. The shared hand-drawn check settles into a saved stamp, alongside the existing towel-hanging illustration. Done is available immediately; no celebratory delay blocks leaving. The animation and success feedback occur after persistence succeeds, preserving the existing failure/retry flow.
- The completion screen reads as a dated page in the workout record: routine name, recorded duration, working sets, warm-ups and cardio. Only relevant metrics appear. Warm-up-only exercises are retained in the details, and fractional cardio minutes are displayed instead of rounded down to zero. Empty sessions have a factual empty-state message without an empty disclosure.
- Copy remains stable and informative: “Session saved” confirms the action. The existing tested `SessionObservation` rules supply at most one meaningful factual highlight; an ordinary session gets no filler message or randomized praise.
- Details wrap at large sizes, metrics stack when space is limited, and the persistent Done button reserves scroll space. Decorative artwork and the stamp are hidden from accessibility; metrics expose label/value pairs. Reduce Motion disables the new decorative motion and save transition (source-reviewed).

Validation: 71 existing tests passed, including session-transition and factual-observation regressions; the iOS Simulator Debug build succeeded. In the isolated audit simulator, saved a partial session with two working sets, expanded its details, reached the final set at maximum text size, and used Done to return to Today with no active-session resume prompt. A second synthetic session containing one warm-up and a 0.15-minute walk displayed both accurately; its final cardio detail cleared Done at maximum text size. Returned the simulator to standard text size. Physical haptic feel and VoiceOver speech remain skipped by request.

### Physical VoiceOver reference sequence (skipped)

Retained for reference only; no physical-device testing is required for this audit.

1. With VoiceOver enabled, swipe through Today; confirm Resume/Start and both tabs are reachable, and the selected tab is announced.
2. Open History, a workout, then an exercise. Confirm each screen title, Back, and Edit are reachable, and Back returns one level. Use the headings rotor on progress and three-finger scroll to the final content.
3. Open Edit. Navigate date/time, set-type pickers, load/repetition fields, remove/add controls, and cardio fields. Confirm exercise/set context and current values are spoken; edit a test value, dismiss the keyboard, and check Cancel/Save focus.
4. Resume a test workout, complete and uncomplete a set, adjust/skip rest, then open and cancel Finish. Check focus returns to the relevant control and the timer does not repeatedly interrupt speech. Pause and resume, confirming recorded values remain intact.

Apple guidance used as the review baseline: [Alerts](https://developer.apple.com/design/human-interface-guidelines/alerts), [Undo and redo](https://developer.apple.com/design/human-interface-guidelines/undo-and-redo), and [Writing](https://developer.apple.com/design/human-interface-guidelines/writing).
