# Form iOS — navigation and flow proposal

Status: implemented in native SwiftUI, based on /mobile-study.html.

## Intent

Bring the homepage's white space, simple round paper character, indigo ink, salvia blue and quiet physical motion into a usable workout companion. Preserve the original character; the clothed character study was rejected. Keep workout data and controls readable with system type; reserve handwriting for short headings and atmospheric captions.

The routine is already prescribed for the supplied gym. No goal questionnaire, equipment setup, workout generator or exercise swapping in the main flow. Existing stored workouts must survive the redesign.

## Navigation

Two persistent bottom destinations: Today and History. A small settings control in the upper right opens a sheet. Native navigation behavior, labeled tabs, accessible touch targets, no hidden swipe-only menus. Treat the selected tab like a small paper marker without introducing a decorative navigation scene.

Today is the entry point even when the user is not training that day. Show one small character vignette, the next session's short summary and one primary action: Start session. A secondary View routine link opens the fixed A/B routine. Avoid a dashboard of statistics or a calendar that implies missed obligations. Do not require a routine preview before starting.

History lists saved sessions by date. Opening one shows its recorded exercises and cardio; selecting an exercise opens its existing progress view. Empty history uses a small quiet illustration and one line of copy, not sample achievements.

Settings holds load increment, screen-awake preference and optional Apple Health/iCloud status. Use existing service behavior. Request any Health permissions when the user connects it, not on first launch.

## Main flow

Today -> Start session -> Weights -> Cardio -> Summary -> Today.

An unfinished session replaces Start session with Resume session. Restore saved position and entered values after interruption. Never create a duplicate session on resume.

Weights shows one exercise at a time: name, prescribed sets and rep range, previous performance when available, and editable actual load/reps. Completing a set starts an inline rest timer. Advancing after the final set is explicit. A compact exercise-list control allows revisiting earlier sets or skipping an exercise. Those actions affect the current session, not the prescribed routine.

Cardio follows weights: 15-minute treadmill walk, speed 5 and incline 7.5. Console units remain unconfirmed; do not label these as confirmed km/h or percent. Allow recording the actual duration and settings or skipping cardio. Suggested values are distinct from completed data.

Summary shows only what was recorded. Finishing saves once; repeat taps must not duplicate records. A short character settling animation is optional and never blocks Done. Partial sessions are saved honestly. Discard does not advance the routine. A saved session advances the proposed A/B sequence; explicit partial completion uses the same behavior, with the next session visible on Today.

The bottom tabs disappear during the active session. A labeled Close control returns to Today with progress retained. Discard is a separate deliberate action. A/B labels are useful in the routine sheet and session details; they do not need to dominate the illustrated home screen.

## Motion and material

Today: one small paper vignette with a little movement and long stillness. No waiting for animation before accessing a control.

Training: stable inputs and numbers. Paper motion belongs at transitions and rest, away from the tapping area. No animated background behind logging controls.

Completion: a quiet exhale or settling gesture; no confetti, streak punishment or mandatory celebration.

Use restrained overlapping edges and shadows, not a card around every item. Support Reduce Motion, Dynamic Type, VoiceOver and high-contrast text. White background remains white.

## Implementation order

1. Today/History navigation shell, routine sheet, settings entry and resume state.
2. Single-exercise logging flow and inline rest.
3. Cardio and save/summary flow.
4. History detail and progress styling.

All four stages are now connected in the native app. Today/History replace the planner and equipment tabs; the fixed sessions are defined by FormRoutine. Legacy saved sessions still resume with their original exercises. New sessions alternate A/B based on the latest saved prescribed session; discarding does not advance that sequence.

The logger presents one exercise at a time with editable set rows, a primary Complete set action, optional set tools and movement notes. Logging a set opens the illustrated rest state; Continue returns to the next set or exercise. The session list supports revisiting exercises, moving to cardio and finishing a partial session. Cardio uses an actual walking timer and a manual entry option. The completion view keeps the recorded totals visible and exercise details in a disclosure.

All eight approved exercise illustrations and the five app vignettes are bundled in the app asset catalog at native resolution. Gaegu is bundled for short headings; workout inputs remain system type. Unknown legacy exercises use the journal vignette rather than an unrelated exercise pose. Illustrations are decorative to VoiceOver; headings and controls carry their context. Static logging artwork, restrained arrival motion and Reduce Motion support keep controls stable.

Validation: iOS Simulator build and core regression suite, plus simulator checks for legacy-session resume, walking, partial save/summary, fresh-session entry, set completion/rest, exercise navigation, History and saved-record detail. Physical-device and larger Dynamic Type review remain before release.
