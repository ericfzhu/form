# Live Activity implementation

Local design reference: /live-activity-study.html. The approved direction is now implemented in the native FormLiveActivity extension.

## Presentations

- Compact: blue paper-plate mark, trailing rest countdown / completed-exercise count / cardio elapsed time / pause symbol.
- Minimal: blue plate only, without small text or decorative motion.
- Expanded: black system background, light readable type, activity phase, current or next exercise, one clearly labeled timer and an Open link.
- Lock Screen: white activity surface, small illustration from the accepted app artwork, the same contextual information and an Open session link.

Rest is the default preview. Switch among lifting, resting, rest finished, walking and paused. Values are illustrative, not a functional workout session.

## Implemented behavior

Minimizing keeps the session and walking timers running. Explicitly leaving the session pauses them. Rest countdowns stop at zero; expired rest is retained for the Ready presentation until the user continues or logs another set. Completed/discarded sessions end their activity. Opening uses a validated session link to return to the matching saved session. Set entry stays in the app.

During rest, show the next set of the current exercise unless that exercise is complete; only then show the next exercise. The study illustrates rest after the final squat set.

The treadmill section now supports an actual elapsed walking timer. Finishing the walk records its duration; suggested speed and incline are not silently recorded as measured values.

## State and resources

LiveWorkoutState is shared by the app and extension. It derives lifting, resting, ready, walking and paused presentations from persisted timer state. New optional fields preserve decoding of older payloads. ActivityKit mutations are serialized. The extension bundles Gaegu and static artwork derived from the accepted exercise illustrations, with the #139 palette and a native vector plate mark.

## Validation and remaining device checks

The iOS Simulator build passes, along with 10 new state/timer/link tests and 19 existing core tests. Simulator review covered the compact countdown while backgrounded, Lock Screen layout, and returning to a saved session with the logged set and walking timer preserved. WidgetKit previews include compact, minimal, expanded and Lock Screen states.

Rest expiry has a local deadline update while the app can execute, plus WidgetKit stale-state handling and an update on returning to the foreground. iOS may delay changing the label to Ready when the app is suspended; the bounded countdown still stops at zero. No remote push service is included. The final deadline-refresh adjustment is build- and unit-tested; its background timing still needs physical-device verification.

Check expanded/minimal presentation, larger accessibility sizes, Always-On appearance and suspension behavior on a physical iPhone before release. System presentation and available space vary; HTML dimensions are illustrative. Artwork stays static in Live Activities and is hidden at accessibility text sizes to prioritize workout information.

Primary reference: https://developer.apple.com/design/human-interface-guidelines/live-activities
