// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FormCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FormCore", targets: ["FormCore"])
    ],
    targets: [
        .target(
            name: "FormCore",
            path: "Form",
            exclude: [
                "Info.plist",
                "Planning/PlannerStore.swift",
                "Planning/PlannerViews.swift",
                "ActiveWorkoutView.swift",
                "AppModelContainer.swift",
                "CoachingReport.swift",
                "ExerciseProgressView.swift",
                "FormApp.swift",
                "Form.entitlements",
                "HealthKitService.swift",
                "HealthSyncCoordinator.swift",
                "HistoryView.swift",
                "RestFeedbackService.swift",
                "RootView.swift",
                "WorkoutActivityAttributes.swift",
                "WorkoutBackup.swift",
                "WorkoutFormatting.swift",
                "WorkoutLiveActivityController.swift",
                "DesignSystem.swift",
                "TrainHomeView.swift",
                "RoutineDetailView.swift",
                "NavigationComponents.swift",
                "ActiveWorkoutActions.swift",
                "WorkoutCompletionView.swift",
                "CardioLoggingComponents.swift",
                "WorkoutLoggingComponents.swift",
                "SetLoggingComponents.swift",
                "RestTimerView.swift",
                "HistorySharingViews.swift",
                "HistorySummaryViews.swift",
                "HistoryConsistencyView.swift",
                "WorkoutHistoryDetail.swift",
                "WorkoutEditorView.swift",
                "ProgressionEngine.swift",
                "ProgressComponents.swift"
            ],
            sources: [
                "Models.swift",
                "WorkoutCatalog.swift",
                "WorkoutSessionState.swift",
                "ActiveSessionStore.swift",
                "WorkoutRepository.swift",

                "Planning/WorkoutPlanning.swift",
                "ActiveDuration.swift",
                "LiveWorkoutState.swift",
                "HealthDistanceWindowPlanner.swift",
                "ProgressPeriod.swift",
                "ProgressionRules.swift"
            ],
            resources: [.copy("Planning/exercises.json")],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "FormCoreTests",
            dependencies: ["FormCore"],
            path: "Tests/FormCoreTests"
        )
    ]
)
