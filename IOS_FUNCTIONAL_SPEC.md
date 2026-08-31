# Form iOS Application — Functional Specification

## 1. Purpose

Form is an offline-first iPhone application for following a fixed three-workout strength programme, recording completed training, resuming interrupted sessions, and reviewing progress over time.

This document describes only what the current iOS application does. It intentionally excludes interface layout, visual styling, colour, illustration, animation, and user-facing prose.

## 2. Product boundaries

| Area | Current behaviour |
| --- | --- |
| Platform | iPhone, portrait orientation, iOS 17 or later |
| Programme | Three fixed routines: Workout A, Workout B, and Workout C |
| Rotation | Repeats in the order A → B → C → A |
| Active sessions | At most one resumable workout session at a time |
| Completed-workout storage | Local SwiftData store on the device |
| Active-session storage | Separate versioned JSON snapshot stored locally on the device |
| Account system | None |
| Custom backend | None |
| iCloud history sync | Not active in the current implementation; the model container is configured for local storage |
| Apple Health | Optional integration for reading body mass and writing or deleting workouts |
| Programme editing | Not supported; routines and prescriptions are defined in the app source |

## 3. Primary navigation

The application has two top-level functional areas:

1. **Training**
   - Shows the workout rotation.
   - Identifies the next workout.
   - Opens routine details.
   - Starts or resumes an active workout.
   - Contains training and integration settings.

2. **Record**
   - Shows all completed workouts.
   - Shows summary and consistency statistics.
   - Opens individual workout records.
   - Opens exercise-specific progress.
   - Exports reports and backups.
   - Restores workout history from a backup.

Each top-level area maintains its own navigation path. The top-level selector is only shown at the root of each area.

## 4. First launch and application startup

### 4.1 First-launch introduction

On first launch, the app presents an introduction explaining:

- the A/B/C rotation;
- set logging and reuse of previous values;
- active-session preservation and resumption.

Completion is stored locally so the introduction is not shown again.

### 4.2 Startup maintenance

At startup, the app:

- migrates legacy workout and exercise identifiers into the current data format;
- refreshes Apple Health connection state and the latest available body mass;
- retries queued Apple Health saves and deletions when access is available;
- ends any orphaned Live Activity when there is no resumable active-session snapshot.

## 5. Workout programme

### 5.1 Rotation logic

The app determines the next workout from the most recently completed workout:

| Most recent completed workout | Next workout |
| --- | --- |
| None | Workout A |
| Workout A | Workout B |
| Workout B | Workout C |
| Workout C | Workout A |
| Unknown or unmappable routine | Workout A |

The app also shows when each routine was last completed.

### 5.2 Fixed routine catalogue

#### Workout A

| Exercise | Prescription | Rest |
| --- | --- | --- |
| Barbell Back Squat | 3 × 6–10 | 180 seconds |
| Dumbbell Chest Press | 3 × 6–10 | 120 seconds |
| Seated Cable Row | 3 × 8–12 | 90 seconds |
| Romanian Deadlift | 2 × 8–10 | 150 seconds |
| Lat Pulldown | 2 × 8–12 | 90 seconds |
| Plank | 2 × 30–45 seconds | 60 seconds |

#### Workout B

| Exercise | Prescription | Rest |
| --- | --- | --- |
| Conventional Barbell Deadlift | 3 × 5–6 | 180 seconds |
| Incline Dumbbell Press | 3 × 8–12 | 120 seconds |
| Underhand Lat Pulldown | 3 × 8–12 | 90 seconds |
| Split Squat | 2 × 8–12 | 120 seconds |
| Chest-Supported Row | 2 × 8–12 | 90 seconds |
| Side Plank | 2 × 30–45 seconds | 60 seconds |

#### Workout C

| Exercise | Prescription | Rest |
| --- | --- | --- |
| Goblet Squat | 3 × 8–12 | 120 seconds |
| Dumbbell Shoulder Press | 3 × 8–12 | 120 seconds |
| Cable Row | 3 × 8–12 | 90 seconds |
| Leg Curl | 2 × 10–15 | 75 seconds |
| Push-Up | 2 × 8–15 | 75 seconds |
| Farmer Carry | 3 × 30–45 seconds | 90 seconds |

### 5.3 Exercise measurement types

The catalogue supports four exercise measurement modes:

| Measurement mode | Recorded values | Examples |
| --- | --- | --- |
| Weighted | Load and repetitions | Squat, press, row |
| Weighted and timed | Load and seconds | Farmer carry |
| Bodyweight | Repetitions | Push-up |
| Timed | Seconds | Plank, side plank |

For dumbbell and unilateral exercises marked as per-hand movements, the recorded load represents the weight of one dumbbell or one hand.

Each catalogue exercise also contains three form cues that can be displayed in its progress view.

## 6. Training home

The training home provides the following functions:

- identifies the next workout in the A/B/C rotation;
- provides access to all three routine templates;
- shows the most recent completion date for each routine;
- detects a saved active session and offers to resume it;
- displays the active session's start time and number of completed sets;
- lets the user configure the progression load increment;
- lets the user choose whether the display remains awake during an active session;
- displays current local/iCloud storage status;
- displays Apple Health connection, latest body mass, queued sync jobs, and sync errors;
- lets the user request Apple Health access, refresh Health data, or open system settings after access is denied.

Available progression increments are 1, 1.25, 2, 2.5, and 5 kilograms. The default is 2.5 kilograms.

## 7. Routine details

Opening a routine provides:

- the complete ordered exercise list;
- prescribed sets and repetition or time range for each exercise;
- the latest recorded top set for each exercise, when available;
- navigation from an exercise to its exercise-progress view;
- an action to begin the workout.

### 7.1 Starting a workout

If there is no active session, the selected routine starts immediately.

If another session is already active, the app requires the user to choose one of the following:

- resume the existing session;
- discard the existing session and start the selected routine;
- cancel and keep the existing session unchanged.

An invalid snapshot whose routine no longer exists is cleared before a new session begins.

## 8. Active workout session

### 8.1 Session initialization

When a new session begins, the app:

- creates the prescribed number of working sets for every exercise;
- initializes repetitions or seconds to the exercise's minimum target;
- pre-fills load and repetitions or seconds from the most recent completed working sets for the same exercise;
- expands the first exercise;
- starts the active-duration timer;
- persists an initial resumable snapshot;
- starts or updates the workout Live Activity;
- optionally prevents the display from sleeping.

When a session is resumed, the saved set values, completion state, cardio entries, expanded exercise, active duration, and unfinished rest timer are restored. Historical pre-fill is not reapplied over resumed values.

### 8.2 Exercise logging

For each exercise, the user can:

- expand or collapse the exercise;
- see the prescribed target;
- see the number of completed prescribed working sets;
- see the previous completed performance;
- see the current progression recommendation;
- enter load where the measurement type supports load;
- enter repetitions or seconds;
- mark a set complete or incomplete;
- change a set between warm-up and working;
- add another working set;
- add a warm-up set;
- delete an added set or a warm-up set;
- copy the first working set's load and repetitions or seconds into all remaining incomplete working sets.

Only completed sets are written to the final workout record.

Warm-up sets are retained in the completed record but do not count toward prescribed-movement completion, progression calculations, working-set totals, or personal records.

An exercise is considered complete when its number of completed working sets reaches its prescribed set count. Extra completed working sets are allowed.

When an exercise becomes complete, the app expands the next incomplete exercise. If necessary, it wraps to an earlier incomplete exercise.

### 8.3 Numeric entry controls

While a load, repetition, or time field is focused, the app provides controls to:

- move to the previous input field;
- move to the next input field;
- decrease the current value;
- increase the current value;
- dismiss the keyboard.

Load changes use the configured load increment. Repetition and time changes use increments of one. Values cannot be reduced below zero.

### 8.4 Cardio logging

A strength session can contain zero or more cardio entries.

Supported cardio types are:

- treadmill walking;
- treadmill running;
- cycling;
- elliptical;
- rowing;
- other cardio.

Each cardio entry can record:

- duration in minutes;
- distance in kilometres;
- average speed in kilometres per hour;
- incline percentage for treadmill walking or running.

The user can add multiple cardio entries and delete any entry. A cardio entry is saved only when its duration is greater than zero.

### 8.5 Rest timer

Completing a set starts the exercise's prescribed rest timer.

- A completed working set uses the full prescribed rest duration.
- A completed warm-up set uses the lower of 90 seconds or the prescribed duration.
- The timer can be extended by 30 seconds.
- The timer can be reduced by 30 seconds.
- The timer can be skipped.
- Reducing the timer to the current time or earlier clears it.
- Reaching zero clears the timer and produces success haptic feedback in the foreground.

The app requests notification permission when needed and can schedule a local rest-complete notification containing the current exercise name. Pending rest notifications are cancelled when the timer is skipped, the session is discarded, or the session finishes.

### 8.6 Active duration

Workout duration measures active in-app session time rather than total wall-clock time.

- The timer resumes when the active-workout screen appears.
- The timer pauses when the session is saved and closed or when the active-workout screen disappears.
- Accumulated active duration is preserved in the session snapshot.

### 8.7 Save, close, discard, and finish

The user can leave an active session in three ways:

1. **Save and close**
   - Pauses the active-duration timer.
   - Persists the complete active snapshot.
   - Keeps the session available to resume.
   - Changes the Live Activity to a paused state.

2. **Discard**
   - Requires destructive confirmation.
   - Deletes the active snapshot.
   - Cancels rest feedback.
   - Ends the Live Activity.
   - Does not create a completed workout record.

3. **Finish**
   - Requires confirmation if no work was recorded.
   - Requires confirmation if not all prescribed movements are complete.
   - Saves only completed sets and cardio entries with a positive duration.
   - Creates a completed workout record.
   - Deletes the active snapshot.
   - Cancels the rest timer and notifications.
   - Ends the Live Activity.
   - Queues the record for Apple Health synchronization when it contains training data.

If saving fails, the active session remains available and the app reports that no session data was lost.

## 9. Active-session persistence and recovery

The app maintains one resumable active-session snapshot in Application Support as an atomically written, versioned JSON file.

The snapshot contains:

- session identifier;
- routine identifier;
- original start date;
- accumulated active duration;
- every exercise's set values, types, and completion states;
- cardio entries and their values;
- expanded exercise identifier;
- unfinished rest-timer end date.

Snapshot changes are saved after a short debounce, and important lifecycle actions save immediately. A legacy UserDefaults snapshot is automatically migrated into the current file format.

## 10. Workout completion summary

After a session is saved, the app shows:

- session date and time;
- active duration in minutes;
- number of movements with completed working sets;
- number of completed working sets;
- Apple Health synchronization status;
- each completed exercise and its saved sets;
- comparison with the previous performance for that exercise;
- up to two newly achieved personal-record indicators per exercise;
- total cardio minutes when cardio was recorded.

## 11. Completed-workout record

### 11.1 Session list

The record's session view:

- lists every completed workout in reverse chronological order;
- shows the workout date, name, duration, number of recorded movements, and cardio duration;
- shows pending or failed Apple Health status when applicable;
- opens the full workout detail;
- supports deletion by swipe action or context menu.

Deleting a workout removes its exercises, sets, and cardio from local storage through cascade deletion. It also queues deletion of the corresponding Apple Health workout.

### 11.2 Record overview

The overview provides:

- current-week completed-session count;
- current-week active minutes;
- current-week completed working-set count;
- the next workout in the A/B/C rotation;
- the number of personal records achieved during the current week;
- a navigable monthly calendar showing how many sessions occurred on each day;
- a twelve-week consistency view showing session count per week;
- total active weeks and total sessions across the twelve-week window;
- access to exercise progress;
- coaching-report export;
- workout-backup export and restore.

The calendar can navigate backward by month and forward up to the current month.

### 11.3 Empty record

When no completed workouts exist, the record shows an empty state and provides access to restore a JSON backup.

## 12. Individual workout detail

Opening a completed workout shows:

- workout date;
- Apple Health synchronization status;
- all exercises containing at least one working set;
- every saved warm-up and working set in recorded order;
- personal-record indicators for each exercise;
- all cardio entries and their available time, distance, speed, and incline values;
- navigation from a known catalogue exercise to its progress view;
- an action to edit the workout.

## 13. Editing a completed workout

The workout editor supports:

- setting or removing an optional custom session title;
- changing the workout date and time;
- changing the workout duration;
- adding exercises from the fixed exercise catalogue;
- removing exercises;
- editing set load and repetitions or seconds;
- changing set type between warm-up and working;
- adding sets;
- removing sets;
- adding, editing, and removing cardio entries.

The editor warns before discarding unsaved changes.

On save, the app:

- clamps duration to at least one minute;
- clamps load, repetitions, time, and cardio values to zero or greater;
- removes incline from cardio types that do not support it;
- replaces the workout's existing exercise, set, and cardio records with the edited values;
- marks the workout for Apple Health synchronization when it contains training data;
- replaces the previously synchronized Apple Health workout rather than creating a lasting duplicate.

The editor changes completed records only. It does not modify the fixed A/B/C routine templates.

## 14. Exercise progress

### 14.1 Exercise discovery

The user can search the fixed exercise catalogue by exercise name and open any exercise's progress view.

Exercise progress can also be opened from:

- a routine detail;
- an individual completed workout.

### 14.2 Time periods

Progress can be filtered to:

- the past 12 weeks;
- the past 6 months;
- the past year;
- all time.

Future-dated workout records are excluded from these periods.

### 14.3 Progress inputs

Exercise progress uses completed working sets only. Warm-up sets and incomplete active-session sets are excluded.

For each exercise appearance, the app derives:

- highest-load set;
- best repetition or time result;
- total recorded volume, calculated as load × repetitions across working sets;
- estimated one-repetition maximum using `load × (1 + repetitions / 30)`.

### 14.4 Progress outputs

Depending on exercise type, the progress view provides:

- number of recorded sessions in the selected period;
- best performance;
- estimated one-repetition maximum for weighted exercises;
- latest performance date;
- current progression recommendation;
- selectable trend charts;
- chronological session history;
- personal-record indicators;
- the exercise's prescribed target;
- the latest recorded performance;
- form cues.

Available chart metrics are:

| Exercise type | Metrics |
| --- | --- |
| Weighted | Load, estimated 1RM, repetitions, volume |
| Weighted and timed | Load, time |
| Bodyweight | Repetitions |
| Timed | Time |

When only one performance exists in the selected period, the app shows it as a baseline and waits for another session before drawing a trend.

### 14.5 Personal records

The app can identify:

- highest load;
- highest estimated one-repetition maximum;
- highest session volume;
- highest repetition count;
- longest recorded time.

A performance is marked as a personal record only when it exceeds at least one earlier performance. The first recorded performance establishes a baseline and is not labelled as a personal record.

## 15. Progression recommendations

The recommendation engine uses the fixed prescription, recent completed working sets, and the user-selected load increment.

### 15.1 Weighted exercises

- Increase load when every prescribed set reaches the top of the repetition range with a positive load.
- The recommended increase is based on the highest load used in the latest session plus the configured increment.
- Reduce load when the minimum target is missed in each of the two latest sessions, including sessions with fewer than the prescribed number of sets.
- Otherwise keep the current load and attempt to add repetitions within the target range.

### 15.2 Weighted timed exercises

- Request a load when no positive load was recorded.
- Increase load when every prescribed set uses the current load and reaches the maximum target time.
- Reduce load after two consecutive sessions below the minimum requirements.
- Otherwise keep the current load and build time.

### 15.3 Bodyweight and timed exercises

- Bodyweight exercises recommend adding a repetition.
- Timed exercises recommend adding time.

## 16. Apple Health integration

Apple Health integration is optional.

### 16.1 Permissions and reads

The app requests permission to:

- write workouts;
- write walking/running distance;
- write cycling distance;
- write rowing distance on iOS 18 or later;
- read the latest body-mass sample.

The latest body mass is displayed as contextual information only. It is not currently used in progression calculations.

### 16.2 Workout writes

When a completed or edited record contains at least one working set or positive-duration cardio entry, the app can create an indoor Apple Health workout.

The Health workout type is selected as follows:

- traditional strength training when the record contains working strength sets;
- otherwise walking, running, cycling, elliptical, rowing, or other from the first cardio entry.

The saved Health workout includes:

- workout start date;
- duration;
- an external identifier linking it to the Form record;
- eligible walking/running, cycling, and rowing distance samples.

Cardio distance samples are assigned sequential time windows within the workout duration.

### 16.3 Synchronization queue

Apple Health saves and deletions use a persistent local queue.

- Failed jobs remain queued.
- Pending, syncing, synced, and failed states are stored on each workout record.
- Queued work is retried when the app starts and when Health access becomes available.
- A newer save replaces an older unsent save for the same local workout.
- A delete supersedes unsent saves for the same workout.
- Editing a synced workout replaces the prior Health workout.
- Deleting a local workout also attempts to delete its Health counterpart by Health UUID or external identifier.

Health failures do not prevent the local workout from being saved.

## 17. Live Activity and Dynamic Island

When Live Activities are enabled, starting a workout creates a Live Activity that can show:

- routine name;
- current exercise;
- completed movement count;
- total movement count;
- running session duration;
- active rest countdown;
- paused state and accumulated active duration.

The Live Activity updates as the active session changes.

- Saving and closing a session leaves a paused Live Activity for the resumable session.
- Resuming the same session updates the existing activity.
- Starting a different session ends the previous activity.
- Finishing or discarding the session ends the activity immediately.
- Live Activity failures never block workout logging.

## 18. Coaching report export

The app can export a Markdown coaching report covering the previous 12 weeks.

The report contains:

- generation date;
- reporting period;
- completed-session count;
- total training minutes;
- total completed working sets;
- total recorded weighted volume;
- the complete current A/B/C programme and prescriptions;
- an exercise summary with appearance count and latest completed sets;
- a chronological session section containing exercises, warm-up sets, working sets, and cardio details.

## 19. Backup and restore

### 19.1 Export

The app can export all completed workout history as a versioned JSON file. The backup includes:

- stable workout identifier;
- date and duration;
- routine identifier and name;
- optional custom title;
- exercises and their stable identifiers;
- set order, load, repetitions or time, and set type;
- cardio type, order, duration, distance, speed, and incline.

### 19.2 Restore

The app can import a version-1 Form JSON backup.

- Existing records are deduplicated by stable workout identifier.
- Existing records are never overwritten by restore.
- Only new records are inserted.
- Imported records are marked as local-only rather than automatically queued for Apple Health.
- Unsupported backup versions are rejected.

## 20. Data model

### 20.1 Completed workout

A completed workout stores:

- stable local/Health synchronization identifier;
- optional Apple Health workout UUID;
- Health synchronization status and error metadata;
- date;
- routine identifier;
- routine name;
- optional custom session title;
- active duration;
- ordered exercise records;
- ordered cardio records.

### 20.2 Exercise record

An exercise record stores:

- stable exercise identifier;
- exercise name;
- demonstration-asset identifier;
- order within the workout;
- ordered set records.

### 20.3 Set record

A set record stores:

- order within the exercise;
- load;
- repetitions or seconds;
- warm-up or working classification.

### 20.4 Cardio record

A cardio record stores:

- cardio type;
- order within the workout;
- duration;
- distance;
- average speed;
- incline.

Deleting a workout cascades to its exercise, set, and cardio records.

## 21. Functional invariants

The current implementation depends on the following rules:

1. Workout A, B, and C have stable identifiers `A`, `B`, and `C`.
2. Exercises have stable identifiers independent of their displayed names.
3. The next-workout decision comes from the latest completed workout, not the active snapshot.
4. Only one active-session snapshot exists at a time.
5. Only completed sets are saved when an active workout is finished.
6. Only working sets determine exercise completion, progression, personal records, and working-set totals.
7. Cardio entries require a positive duration to be saved.
8. Local workout saving succeeds independently of Apple Health synchronization.
9. Editing or deleting a synced workout must enqueue the corresponding Health replacement or deletion.
10. Backup restore deduplicates by the workout's stable synchronization identifier.

## 22. Current implementation constraints

- The programme cannot be created, reordered, or edited by the user.
- Exercises cannot be created outside the fixed catalogue.
- The app does not support simultaneous active workouts.
- The current model-container code uses local SwiftData storage only; there is no active CloudKit configuration or iCloud entitlement.
- The resumable active session is local to one device and is not part of the completed-workout database.
- The app has no Form account and no custom network service.
- Exercise progress does not include incomplete active-session data.
- Exercise progress is available only for exercises that can be mapped to the fixed catalogue.
- Apple Health body mass is displayed but does not affect recommendations.
- Apple Health synchronization requires authorization and can remain pending or failed without affecting local history.

## 23. Source-of-truth files inspected

This specification was derived from the current implementation in:

- `Form/FormApp.swift`
- `Form/RootView.swift`
- `Form/TrainHomeView.swift`
- `Form/RoutineDetailView.swift`
- `Form/ActiveWorkoutView.swift`
- `Form/ActiveWorkoutActions.swift`
- `Form/WorkoutSessionState.swift`
- `Form/WorkoutRepository.swift`
- `Form/WorkoutLoggingComponents.swift`
- `Form/SetLoggingComponents.swift`
- `Form/CardioLoggingComponents.swift`
- `Form/RestTimerView.swift`
- `Form/WorkoutCompletionView.swift`
- `Form/HistoryView.swift`
- `Form/HistorySummaryViews.swift`
- `Form/HistoryConsistencyView.swift`
- `Form/WorkoutHistoryDetail.swift`
- `Form/WorkoutEditorView.swift`
- `Form/ExerciseProgressView.swift`
- `Form/ProgressionEngine.swift`
- `Form/ProgressionRules.swift`
- `Form/WorkoutCatalog.swift`
- `Form/Models.swift`
- `Form/ActiveSessionStore.swift`
- `Form/HealthKitService.swift`
- `Form/HealthSyncCoordinator.swift`
- `Form/WorkoutBackup.swift`
- `Form/CoachingReport.swift`
- `Form/WorkoutLiveActivityController.swift`
- `FormLiveActivity/FormLiveActivity.swift`

