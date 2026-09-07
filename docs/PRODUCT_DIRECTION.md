# Form: a little plan, a good session

## Purpose
Help Eric plan workouts around the equipment actually available at his gym. The core flow is: review gym → choose rhythm → review a session → swap movements → train → return to the record. The website is a usable local planning companion, not a canvas presentation or a download advertisement. The iPhone remains the place to log and resume workouts.

## Initial gym inventory
Taken from Eric's descriptions on 7 September 2026, not independent verification of machine models:

- Free barbell and plates, power rack, adjustable bench (also usable flat)
- Plate-loaded seated leg curl
- Adjustable high–low pulley, lat pulldown, seated cable row station
- Upright bike, elliptical, rowing machine and treadmill
- Dumbbells and leg press are **not** assumed available

The initial rhythm is three sessions per week, a 45-minute budget, and “Find a rhythm.” These are editable starting settings, not stated user preferences. iOS asks the user to review the seeded gym before creating a plan. The web starts with this inventory and lets it be edited immediately.

## Planning behavior
- One shared exercise inventory: `Form/Planning/exercises.json`.
- Every required equipment item must be available. An adjustable bench also qualifies as a flat bench.
- Two to four sessions form an alternating full-body rotation. Session 3 repeats the first emphasis; session 4 repeats the second. No arbitrary daily randomization.
- 30-minute sessions prioritize three movements. Longer budgets allow the second lower-body movement, core, and then leg accessory/carry work.
- Extra sets are reduced before shortening prescribed rest when a budget is tight.
- Time is approximate: five minutes plus 45 seconds per set and prescribed rest. Cardio is outside this estimate.
- Swaps must retain the movement pattern and satisfy equipment requirements. Stale or invalid overrides are ignored.
- Unsupported patterns are named explicitly; the planner never invents access to equipment.
- This is an editable starting template. Training focus adjusts starting rep ranges and volume; it is not individualized coaching or a promise of results.
- Cardio equipment is shown separately. The iPhone cardio picker uses available machines, preserves existing entries, and starts new entries at zero minutes.

## Storage and compatibility
The web saves equipment and swaps in this browser and can export the rotation as text. The iOS gym profile and swaps are stored on-device. These two profiles do not sync with each other. Existing workout history, backup, Health, iCloud and Live Activity mechanisms remain in place. Version 3 active-session snapshots embed the full routine so gym or swap edits cannot mutate a resumed session. Older snapshots still decode. New exercise IDs resolve in the progress/library lookup. An empty workout does not advance the new rotation.

## Visual direction
Palette #139: deep indigo #051230, salvia blue #97ACC8, neutral gray #B6BFC1, with white. Clean sans-serif hierarchy, rounded human accents, restrained strokes, generous margins. One original generated planning character is shared by the website and iOS. Existing exercise demonstrations are retained for now; new movements use a generic activity symbol where a demonstration asset is absent. Their technique artwork has not been regenerated.

## Validation
- `node --test src/planner.test.js`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test`
- `yarn build`
- Local iOS simulator build, without device signing
- Browser checks: equipment controls, valid swaps, persistence and narrow layout

Everything remains local. Do not use Sites or deploy this work.
