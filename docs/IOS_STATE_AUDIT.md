# iOS state and action audit

Reviewed 25–26 October 2026. This is a source review plus targeted regression testing, not a claim that every possible interaction has been verified on a device.

## Persistent-header alignment — 9 November 2026

- Replaced separate Today, History, active-workout and saved-workout brand bars with `CounterweightHeader`: a shared 24-point side inset, 56-point minimum height, explicit 8-point action spacing, and an opaque background covering the top safe area. Trailing actions grow toward the wordmark, keeping the last control anchored at the same right edge.
- Today and History both use zero top-inset spacing. Empty/populated History use the same 24-point page-title inset as Today; the populated list explicitly removes its automatic top content margin. Bottom-tab divider margins use the same page inset.
- Validation: simulator Debug build succeeds; Today/History screenshots show identical wordmark pixels and identical Settings-glyph bounds (375–390 × 164–176 in the captured 456 × 972 window). Their page titles align visually. History Sessions → Overview → bottom scroll → Sessions preserves the header position. No workout data was modified. Existing 82-test result from the preceding pass remains applicable; no model behavior changed and the suite was not repeated for this layout correction.

## Reachable-surface polish — 9 November 2026

This pass follows the routes exposed by the current `RootView` (Today and History), including nested editors and sheets. It is a source inventory plus targeted simulator checks, not a certification of every combination of content, Dynamic Type, VoiceOver and device size.

| Surface | Treatment |
| --- | --- |
| Today, routine, active-session recovery | Existing Counterweight controls and routine/discard sheets retained; Settings now shares the same sheet shell. |
| Workout, focused set, rest, technique, reorder | Rest adjustments read **−30 / +30**, with seconds retained in accessibility labels. Manual rest and keyboard navigation use the shared controls. Reorder retains native drag handles with a plain white list and matching modal chrome. |
| Empty finish / review before saving | Authored confirmation sheets replace alerts. Closing/Keep training does not finalize the session; confirmed save/end executes after dismissal. |
| Completion / saved record | Shared saved surface retained. Details now use a clipped height reveal without fading the contents; View details uses the common capsule. |
| Saved-workout editor | Common type, spacing and controls; set identity/type/removal sit above the numeric fields. Add exercise shows an illustrated picker; set and cardio types use choice sheets. Cancel with edits uses the shared confirmation. Header background covers the status-bar area when scrolling. |
| History sessions / overview | Delete from swipe, long press or accessibility action opens the same confirmation. Calendar arrows, share/backup affordances and empty-state restore match the control system. Calendar accessibility labels include date and session count. |
| Exercise index / progress | Matching modal header, search field and close control; period/metric choice pills and readable system type across technique, recommendations, baseline, trends and empty states. |
| Error and restore notices | Current root/session/editor/history messages use the same sheet shell; message content remains stable while dismissing. |
| System-owned surfaces | Date/time selection, keyboard, share, Files, Health/notification permissions and Live Activity containers retain platform behavior. Live Activity already uses the Counterweight palette and artwork. |

The dormant `PlanHomeView` / `GymProfileView` and their routine-swapping/conflict screens have no launch route in the current app. They are not counted as reachable coverage; re-enabling that product flow requires a separate pass. The legacy routine list now reuses the shared Settings sheet rather than maintaining a second settings design.

Validation: simulator Debug build and all 82 existing regression tests pass. Simulator review covers Settings at both detents; editor set-type, illustrated exercise and cardio pickers; cancelling an unsaved cardio draft back to the original record; History delete cancellation; History overview scrolling to backup actions; and exercise-index navigation to a populated progress baseline. Final-build checks also confirm normal History-row taps, the saved-details reveal, unwrapped editor set types, the opaque header while revealing a lower field, both 30-second rest adjustments, and empty-finish cancellation. The fresh zero-set review workout is left paused on Today with no rest timer running. No saved workout was deleted or edited during these checks. Physical-iPhone testing remains skipped. Native automation does not consistently expose sheets presented over full-screen covers in its accessibility tree, so those sheets were inspected visually; this is not a completed VoiceOver audit.

## Control and motion polish — 9 November 2026

- Exercise changes now animate one clipped reveal layout instead of inserting/removing fading editors. Artwork and header action slots stay the same size. Editors remain mounted, with collapsed content excluded from interaction and accessibility. Automatic animated scrolling on exercise selection is removed; initial restoration and validation-driven field reveal remain.
- Set selection no longer crossfades duplicate input/result views. Selection marks retain their small physical movement; rest remains in its reserved dock. Reduce Motion changes the expanded layout immediately.
- Shared Counterweight capsule and circular controls cover Pause, Edit, set addition, reorder, Today routine/discard/retry/settings, saved-record navigation, and nested editor/progress headers.
- Set and workout three-dot menus, History options, and automatic-rest selection now open authored Counterweight sheets. Set type is a pair of selected/unselected controls, with copy, undo recording and removal grouped below. Routine, Technique and discard confirmation use the same header and close control. History still exposes exercise progress, backup export and restore; Sessions/Overview remain in the visible section control.
- Sheet actions that open another presentation or mutate the current editor run after dismissal. Discard still requires its own explicit confirmation; closing or keeping the sheet preserves the session. System share/import surfaces and error alerts retain platform behavior.

Validation: simulator build and 82 existing regression tests pass. Targeted simulator checks cover Romanian deadlift ↔ incline-press expansion, routine and discard-sheet presentation/cancellation, set-action layout, and History → exercise progress after the action sheet closes. Physical-iPhone checks remain skipped. Timing and feel still warrant user evaluation on the running simulator; this is not a claim of exhaustive animation/accessibility coverage.

## Focused-set interaction pass — 9 November 2026

This supersedes the expanded set-table and inline-rest presentation described in the initial Counterweight pass below.

- Each exercise now has selectable numbered set marks and one focused editor. Logging settles that editor into a recorded result with Edit and an explicit Next set action; there is no automatic advancement. A fully recorded exercise offers Exercises, returning to the list. Any mark remains selectable.
- Set marks have fixed widths so recorded values do not displace their selection targets. Selection uses a short moving outline, entry/result use a local settle, and switching sets uses a short crossfade. Logging feedback never gates persistence or navigation. Reduce Motion removes travel and compression.
- Rest has a reserved bottom dock in idle, running and Ready states, with the same position while switching sets/exercises or scrolling. The keyboard toolbar appears beneath that dock. Auto rest preferences remain per exercise; manual rest uses the selected duration (one minute when automatic rest is off).
- Warm-up and working-set addition are adjacent. Copy-to-remaining, type, unrecord and removal belong to the selected set's menu. Copy intentionally replaces raw target drafts, including invalid strings whose underlying numeric value has not changed, and does not alter recorded sets.
- Technique is a sheet reached from the exercise header. Missing cues for four current routine IDs have been supplied; unsupported legacy exercises do not expose an empty Technique sheet. The old Set options / Movement notes disclosures and repeated generic effort instruction are removed.
- Schema 5 adds the selected set per exercise. Existing schema 1–4 snapshots restore with a sensible selection; removed or invalid selection IDs fall back safely. Keyboard traversal and finish validation select the owning exercise and set before revealing the field.

Verification: iOS Simulator build and 82 automated tests (63 XCTest + 19 Swift Testing). Added cases cover selected-set stability after logging/switching/relaunch, removal and old-snapshot fallback, explicit-copy replacement of an invalid draft, manual rest duration, and technique coverage for the prescribed routine. Simulator checks cover recorded-set editing without restarting rest, explicit Next set, invalid logging, pause/relaunch with the raw draft and selected set preserved, copy into that draft, Technique presentation, warm-up insertion, keyboard traversal between sets, and Finish revealing a hidden invalid recorded set. Physical-iPhone checks remain skipped; this is targeted coverage, not certification of every accessibility/device permutation.

## Counterweight native pass — 9 November 2026

The core journey now uses Counterweight in SwiftUI, with nine distinct exercise/walk assets in both app and Live Activity bundles. The existing A/B prescription, records, editing, progression, backup and Health workflows remain available. Old paper artwork is retained as unused assets rather than deleting historical resources.

- Today starts/resumes directly and links the most recent record. Exercise selection expands in place; reordering, warm-ups, set tools and previous performance remain available.
- Rest is independent, retains its source set across schema-4 snapshots, and is suppressed after the last planned working set. Manual rest remains available. Logging strength no longer finishes an ongoing walk.
- Raw number drafts and their original set identities survive pause/relaunch. Old snapshots still decode. Finish validates recorded work, reviews entered-but-unrecorded values or a running walk, and allows untouched partial routines to save directly. Empty finish clears the snapshot without inserting a History record.
- First completion and History share `SavedWorkoutView`. Only first completion shows/animates the Saved acknowledgement. Editing opens the existing isolated draft editor. Exercise details retain progression links, legacy records, warm-ups and cardio measurements.
- Custom tabs are individual accessible buttons with dedicated space below the retained navigation stacks. The saved-workout Done action is anchored separately from scrolling details. Decorative artwork is hidden from accessibility; exercise buttons announce expansion and recorded/planned counts.

### Motion contract

| Transition | Native treatment | Reduced motion / interruption |
| --- | --- | --- |
| Start / resume / pause | Native full-screen presentation and dismissal | System accessibility transition; no replayed logging effect |
| Press / log / undo | Circular action mark, brief weight compression/release, local exercise artwork response, one haptic on valid logging | Instant state change; no artwork travel or symbol replacement animation |
| Exercise / notes / set tools | Short spring disclosure; stable exercise/set IDs; focused fields reveal their parent | Root transaction removes custom animation; no automatic completion navigation |
| Rest entry / skip / manual rest | Inline panel inserts/removes; keyboard uses compact rest above keyboard controls | Same controls without travel; expiration changes to Ready without navigation |
| Walk / adding or removing rows | Local disclosure and row transition | State updates immediately; timer remains independent |
| Finish / failure | Crossfade to the shared saved surface only after local save; character settles and mark resolves | Static saved state; failure stays in the logger and does not trigger completion feedback |
| Saved details / edit / back | In-place details disclosure; native editor cover and navigation push/pop | No acknowledgement replay after editing or reopening |
| Today / History; Sessions / Overview | Small matched selection dot and brief transition | Selection changes immediately |

Animations never delay persistence or enable/disable actions. The common timing tokens are in `DesignSystem.swift`; the root also removes custom animations for Reduce Motion.

### Evidence for this pass

- iOS Simulator Debug build succeeds with Xcode 26.5 SDK, including the Live Activity extension.
- 77 automated tests pass: 58 XCTest cases and 19 Swift Testing cases. Six added cases cover rest ownership/undo after relaunch, final-set/manual-rest behavior, concurrent walk and strength, raw invalid drafts and baselines, legacy snapshot decoding, and failed-finish rollback of an empty cardio draft.
- Isolated **Form Counterweight Review** simulator: Today → start, field entry, set logging → inline rest with notifications declined, pause with `-` in an unrecorded weight, resume retaining `-` and 35 kg recorded weight, exclusion review, save, details, Done → next routine with no Resume, History → same record without first-save acknowledgement. Both bottom tabs are now individually exposed in the native accessibility tree. The expanded saved record scrolls to its final Health-status row with Done and both tabs visible. Switching to a later exercise retains the recorded set and the original rest source.
- This pass does not certify every permutation, physical haptics, physical VoiceOver, or locked-device delivery. Physical-iPhone checks remain skipped at the user's request. Existing backup/Health failure tests pass, but their system pickers and permission flows were not exhaustively repeated for this visual change.

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

### Today and History personality pass

- Today uses a blue-tinted routine card with handwritten headings, a compact state-specific illustration (arriving, paused, or a session recorded today), and a factual note for the latest saved session. Active sessions show recorded set/cardio counts and their start date. Recovery errors retain Retry, disabled Start and confirmed Discard. The header stays visible while scrolling and covers the status-bar area.
- History groups sessions into chronological month pages, uses handwritten date marks and titles, and exposes Sessions/Overview as ink-underlined controls. Rows remain buttons with their existing confirmed deletion paths. Today and History share a factual summary that includes working sets, warm-ups and fractional cardio minutes rather than showing misleading zero-movement summaries.
- The weekly overview uses the same paper-card treatment, with adaptive metrics and wrapping headings. Empty History has a scrollable illustrated page, a direct explanation and Restore a backup. There are no randomized greetings, repeated praise, entry celebrations or new looping motion on either screen; touch feedback uses the existing Reduce Motion-aware button style.

Validation: 71 existing tests passed, the final simulator build succeeded, and `git diff --check` passed. On the populated iPhone SE audit simulator, checked Today after a saved session, the Sessions/Overview controls and selected traits, October/July grouping, opening an older workout, and scrolling the final July entry above the tabs at maximum text size. Checked the expanded weekly summary and Today’s final record note at maximum text size. Started a synthetic session, recorded one set, paused, and verified the new Today card shows “1 set recorded,” start time and Resume above the tabs. A separate temporary empty simulator verified first-use Today and empty History at normal size, plus the empty-state guidance/Restore action at maximum text size; that temporary device was removed afterward. The populated audit simulator was returned to standard text size. Physical-iPhone checks remain skipped by request.

### Physical VoiceOver reference sequence (skipped)

Retained for reference only; no physical-device testing is required for this audit.

1. With VoiceOver enabled, swipe through Today; confirm Resume/Start and both tabs are reachable, and the selected tab is announced.
2. Open History, a workout, then an exercise. Confirm each screen title, Back, and Edit are reachable, and Back returns one level. Use the headings rotor on progress and three-finger scroll to the final content.
3. Open Edit. Navigate date/time, set-type pickers, load/repetition fields, remove/add controls, and cardio fields. Confirm exercise/set context and current values are spoken; edit a test value, dismiss the keyboard, and check Cancel/Save focus.
4. Resume a test workout, complete and uncomplete a set, adjust/skip rest, then open and cancel Finish. Check focus returns to the relevant control and the timer does not repeatedly interrupt speech. Pause and resume, confirming recorded values remain intact.

Apple guidance used as the review baseline: [Alerts](https://developer.apple.com/design/human-interface-guidelines/alerts), [Undo and redo](https://developer.apple.com/design/human-interface-guidelines/undo-and-redo), and [Writing](https://developer.apple.com/design/human-interface-guidelines/writing).
