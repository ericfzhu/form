import Foundation

struct ExerciseTemplate: Identifiable, Hashable {
    let id: String
    let name: String
    let assetName: String
    let sets: Int
    let minimumRepetitions: Int
    let maximumRepetitions: Int
    let measurement: Measurement

    enum Measurement: Hashable {
        case weighted
        case bodyweight
        case timed
    }

    var targetText: String {
        switch measurement {
        case .timed:
            return "\(sets) × 30–45 sec"
        default:
            return "\(sets) × \(minimumRepetitions)–\(maximumRepetitions)"
        }
    }

    var formCues: [String] {
        WorkoutCatalog.formCues[id] ?? []
    }

    var usesPerHandLoad: Bool {
        [
            "chest-press", "romanian-deadlift", "incline-press",
            "split-squat", "chest-supported-row", "shoulder-press"
        ].contains(id)
    }

    var loadLabel: String {
        usesPerHandLoad ? "KG / HAND" : "KG"
    }
}

struct RoutineTemplate: Identifiable, Hashable {
    let id: String
    let name: String
    let focus: String
    let exercises: [ExerciseTemplate]
}

enum WorkoutCatalog {
    static let formCues: [String: [String]] = [
        "barbell-back-squat": [
            "Set the bar across your upper back and brace before leaving the rack.",
            "Keep your whole foot planted as your knees track over your toes.",
            "Descend under control, then drive the floor away."
        ],
        "chest-press": [
            "Set your shoulder blades gently back against the bench.",
            "Lower the dumbbells beside your chest with your wrists stacked.",
            "Press upward without letting your shoulders roll forward."
        ],
        "seated-row": [
            "Sit tall with a quiet torso and begin with your shoulders relaxed.",
            "Pull your elbows toward your hips without leaning backward.",
            "Return the handle under control and let your shoulder blades move."
        ],
        "romanian-deadlift": [
            "Soften your knees, brace, and keep the weights close to your legs.",
            "Send your hips backward until your hamstrings limit the movement.",
            "Stand by driving your hips forward without leaning back."
        ],
        "lat-pulldown": [
            "Secure your thighs and begin with your ribs stacked over your pelvis.",
            "Draw your elbows down toward your sides, bringing the bar to upper chest height.",
            "Control the return without shrugging at the top."
        ],
        "plank": [
            "Place your elbows below your shoulders and press the floor away.",
            "Keep ribs and pelvis stacked while squeezing glutes and thighs.",
            "End the set when you can no longer hold a straight, braced position."
        ],
        "conventional-deadlift": [
            "Stand with the bar over mid-foot and take your grip outside your legs.",
            "Brace, pull the slack from the bar, and keep it close to your body.",
            "Push the floor away and finish tall without leaning backward."
        ],
        "incline-press": [
            "Use a modest bench incline and keep your feet firmly planted.",
            "Lower the dumbbells with forearms vertical and shoulders supported.",
            "Press up and slightly inward without clashing the dumbbells."
        ],
        "underhand-lat-pulldown": [
            "Take a comfortable underhand grip and secure your thighs.",
            "Keep your chest quiet as your elbows travel down beside your torso.",
            "Use a controlled full reach without losing your shoulder position."
        ],
        "split-squat": [
            "Choose a stance long enough for both feet to remain stable.",
            "Lower mostly straight down while the front knee tracks over the toes.",
            "Drive through the front foot and keep the pelvis level."
        ],
        "chest-supported-row": [
            "Set the bench so your chest remains supported throughout the set.",
            "Begin with long arms, then draw your elbows back without shrugging.",
            "Pause briefly before lowering the weights under control."
        ],
        "side-plank": [
            "Place your elbow below your shoulder and stack or stagger your feet.",
            "Lift your hips until shoulder, hip, and ankle form one line.",
            "Keep your torso facing forward and stop before your hips sag."
        ],
        "goblet-squat": [
            "Hold the dumbbell close to your chest and brace before descending.",
            "Sit between your hips while keeping your whole foot planted.",
            "Drive upward with knees tracking in line with your toes."
        ],
        "shoulder-press": [
            "Start with the dumbbells over your forearms and ribs stacked.",
            "Press overhead without arching your lower back.",
            "Finish with the weights balanced over your shoulders."
        ],
        "cable-row": [
            "Set a stable seated position with a tall, braced torso.",
            "Pull toward your lower ribs while keeping your shoulders away from your ears.",
            "Reach forward under control without rounding aggressively."
        ],
        "leg-curl": [
            "Align your knees with the machine pivot and secure the pad above your heels.",
            "Curl through the largest comfortable range without lifting your hips.",
            "Lower the weight slowly rather than letting the stack drop."
        ],
        "pushup": [
            "Place your hands slightly wider than shoulder width and brace your trunk.",
            "Lower your chest between your hands with elbows angled comfortably back.",
            "Press the floor away while keeping your body moving as one unit."
        ],
        "farmer-carry": [
            "Stand tall with the weights at your sides and shoulders relaxed.",
            "Take short, controlled steps while keeping your ribs stacked.",
            "Turn carefully and stop before your grip changes your posture."
        ]
    ]

    static let routines: [RoutineTemplate] = [
        RoutineTemplate(
            id: "A",
            name: "Workout A",
            focus: "Squat · press · pull",
            exercises: [
                exercise("barbell-back-squat", "Barbell Back Squat", 3, 6, 10),
                exercise("chest-press", "Dumbbell Chest Press", 3, 6, 10),
                exercise("seated-row", "Seated Cable Row", 3, 8, 12),
                exercise("romanian-deadlift", "Romanian Deadlift", 2, 8, 10),
                exercise("lat-pulldown", "Lat Pulldown", 2, 8, 12),
                timed("plank", "Plank", 2)
            ]
        ),
        RoutineTemplate(
            id: "B",
            name: "Workout B",
            focus: "Hinge · incline · unilateral",
            exercises: [
                exercise("conventional-deadlift", "Conventional Barbell Deadlift", 3, 5, 6),
                exercise("incline-press", "Incline Dumbbell Press", 3, 8, 12),
                exercise("underhand-lat-pulldown", "Underhand Lat Pulldown", 3, 8, 12),
                exercise("split-squat", "Split Squat", 2, 8, 12),
                exercise("chest-supported-row", "Chest-Supported Row", 2, 8, 12),
                timed("side-plank", "Side Plank", 2)
            ]
        ),
        RoutineTemplate(
            id: "C",
            name: "Workout C",
            focus: "Squat · shoulders · carry",
            exercises: [
                exercise("goblet-squat", "Goblet Squat", 3, 8, 12),
                exercise("shoulder-press", "Dumbbell Shoulder Press", 3, 8, 12),
                exercise("cable-row", "Cable Row", 3, 8, 12),
                exercise("leg-curl", "Leg Curl", 2, 10, 15),
                bodyweight("pushup", "Push-Up", 2, 8, 15),
                timed("farmer-carry", "Farmer Carry", 3)
            ]
        )
    ]

    static func exercise(named name: String) -> ExerciseTemplate? {
        routines
            .flatMap(\.exercises)
            .first { $0.name == name }
    }

    private static func exercise(_ asset: String, _ name: String, _ sets: Int, _ minimum: Int, _ maximum: Int) -> ExerciseTemplate {
        ExerciseTemplate(id: asset, name: name, assetName: asset, sets: sets, minimumRepetitions: minimum, maximumRepetitions: maximum, measurement: .weighted)
    }

    private static func bodyweight(_ asset: String, _ name: String, _ sets: Int, _ minimum: Int, _ maximum: Int) -> ExerciseTemplate {
        ExerciseTemplate(id: asset, name: name, assetName: asset, sets: sets, minimumRepetitions: minimum, maximumRepetitions: maximum, measurement: .bodyweight)
    }

    private static func timed(_ asset: String, _ name: String, _ sets: Int) -> ExerciseTemplate {
        ExerciseTemplate(id: asset, name: name, assetName: asset, sets: sets, minimumRepetitions: 30, maximumRepetitions: 45, measurement: .timed)
    }
}
