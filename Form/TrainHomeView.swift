import Foundation
import SwiftData
import SwiftUI
import UIKit

struct RoutineListView: View {
    @Query(sort: \WorkoutRecord.date, order: .reverse) private var workouts: [WorkoutRecord]
    @AppStorage("progression-load-increment") private var loadIncrement = 2.5
    @AppStorage("keep-screen-awake") private var keepScreenAwake = true
    @StateObject private var health = HealthKitService.shared
    @StateObject private var healthSync = HealthSyncCoordinator.shared
    @State private var resumeSnapshot: ActiveWorkoutSnapshot?
    @State private var showingResume = false

    private var nextRoutine: RoutineTemplate {
        WorkoutCatalog.nextRoutine(after: workouts.first)
    }

    private var remainingRoutines: [RoutineTemplate] {
        WorkoutCatalog.routines.filter { $0.id != nextRoutine.id }
    }

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    RawScreenTitle(index: "01", title: "Train")
                        .padding(.horizontal, -20)
                        .padding(.bottom, 24)

                    if let resumeRoutine {
                        Button { showingResume = true } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("SESSION IN PROGRESS")
                                        .font(.system(.caption2, design: .serif, weight: .semibold))
                                        .tracking(1.5)
                                        .foregroundStyle(InkPalette.cinnabar)
                                    Text(resumeRoutine.name)
                                        .font(.system(.title3, design: .serif, weight: .semibold))
                                    Text(resumeDetail)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(InkPalette.softInk)
                                }
                                Spacer()
                                Text("CONTINUE")
                                    .font(.system(.caption, design: .serif, weight: .semibold))
                                    .tracking(1.4)
                                    .foregroundStyle(InkPalette.cinnabar)
                                    .frame(minWidth: 54, minHeight: 44)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(InkPalette.raisedPaper)
                            .overlay { Rectangle().stroke(InkPalette.bronze.opacity(0.72), lineWidth: 1) }
                            .overlay(alignment: .top) {
                                Rectangle().fill(InkPalette.cinnabar).frame(height: 3)
                            }
                        }
                        .buttonStyle(PressableButtonStyle())
                        .padding(.bottom, 24)
                    }

                    RawSectionHeader(index: "01", title: "NEXT SESSION")
                        .padding(.bottom, 10)
                    NavigationLink(value: nextRoutine) {
                        RoutineCard(
                            routine: nextRoutine,
                            isRecommended: true,
                            lastCompleted: lastCompleted(nextRoutine)
                        )
                    }
                    .buttonStyle(PressableButtonStyle())
                    .padding(.bottom, 28)

                    RawSectionHeader(index: "02", title: "ROTATION", trailing: "A → B → C")
                        .padding(.bottom, 10)
                    LazyVStack(spacing: 14) {
                        ForEach(remainingRoutines) { routine in
                            NavigationLink(value: routine) {
                                RoutineCard(
                                    routine: routine,
                                    lastCompleted: lastCompleted(routine)
                                )
                            }
                            .buttonStyle(PressableButtonStyle())
                        }
                    }

                    settings
                        .padding(.top, 22)
                    CloudIntegrationSection()
                        .padding(.top, 14)
                    HealthIntegrationSection(health: health, healthSync: healthSync)
                        .padding(.top, 14)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 30)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { resumeSnapshot = ActiveWorkoutStore.load() }
        .task {
            await health.refresh()
            await healthSync.refreshPendingCount()
        }
        .fullScreenCover(isPresented: $showingResume, onDismiss: {
            resumeSnapshot = ActiveWorkoutStore.load()
        }) {
            if let resumeSnapshot, let resumeRoutine {
                ActiveWorkoutView(routine: resumeRoutine, snapshot: resumeSnapshot) {
                    self.resumeSnapshot = nil
                }
            }
        }
    }

    private var settings: some View {
        VStack(spacing: 0) {
            HStack {
                Text("LOAD INCREMENT")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(InkPalette.softInk)
                Spacer()
                Picker("Load increment", selection: $loadIncrement) {
                    ForEach([1.0, 1.25, 2.0, 2.5, 5.0], id: \.self) { value in
                        Text("\(WorkoutValueFormatter.decimal(value)) kg").tag(value)
                    }
                }
                .pickerStyle(.menu)
                .tint(InkPalette.ink)
            }
            .frame(minHeight: 52)
            .padding(.horizontal, 12)

            InkDivider()

            Toggle(isOn: $keepScreenAwake) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("KEEP SCREEN AWAKE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(InkPalette.softInk)
                    Text("While a session is in progress")
                        .font(.system(.caption, design: .serif))
                        .foregroundStyle(InkPalette.softInk.opacity(0.76))
                }
            }
            .tint(InkPalette.cinnabar)
            .frame(minHeight: 58)
            .padding(.horizontal, 12)
        }
        .overlay { Rectangle().stroke(InkPalette.ink, lineWidth: 1) }
    }

    private var resumeRoutine: RoutineTemplate? {
        guard let resumeSnapshot else { return nil }
        return WorkoutCatalog.routine(id: resumeSnapshot.routineID)
    }

    private var resumeDetail: String {
        guard let resumeSnapshot else { return "" }
        let completedSets = resumeSnapshot.exercises.reduce(0) {
            $0 + $1.sets.filter(\.completed).count
        }
        return "Started \(resumeSnapshot.startedAt.formatted(date: .omitted, time: .shortened)) · \(completedSets) sets"
    }

    private func lastCompleted(_ routine: RoutineTemplate) -> Date? {
        workouts.first { $0.routineID == routine.id || $0.routineName == routine.name }?.date
    }
}

private struct CloudIntegrationSection: View {
    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("ICLOUD")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(InkPalette.softInk)
                Text(detail)
                    .font(.system(.caption, design: .serif))
                    .foregroundStyle(InkPalette.softInk.opacity(0.8))
            }
            Spacer()
            Text(status)
                .font(.system(size: 10, weight: .semibold, design: .serif))
                .tracking(1.1)
                .foregroundStyle(InkPalette.cinnabar)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 66)
        .overlay { Rectangle().stroke(InkPalette.ink, lineWidth: 1) }
    }

    private var detail: String {
        switch AppModelContainer.storageMode {
        case .iCloud: "Workout history syncs through your private iCloud database"
        case .localFallback: "Using the on-device store until iCloud is available"
        }
    }

    private var status: String {
        switch AppModelContainer.storageMode {
        case .iCloud: "SYNCING"
        case .localFallback: "LOCAL"
        }
    }
}

private struct HealthIntegrationSection: View {
    @ObservedObject var health: HealthKitService
    @ObservedObject var healthSync: HealthSyncCoordinator

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("APPLE HEALTH")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(InkPalette.softInk)
                    Text(detail)
                        .font(.system(.caption, design: .serif))
                        .foregroundStyle(InkPalette.softInk.opacity(0.8))
                }
                Spacer(minLength: 12)
                Button(actionTitle) { performAction() }
                    .font(.system(size: 10, weight: .semibold, design: .serif))
                    .tracking(1.1)
                    .foregroundStyle(InkPalette.cinnabar)
                    .frame(minWidth: 72, minHeight: 44, alignment: .trailing)
                    .buttonStyle(PressableButtonStyle())
                    .disabled(health.accessState == .unavailable)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 66)

            if let errorMessage = health.errorMessage ?? healthSync.lastError {
                InkDivider()
                Text(errorMessage)
                    .font(.system(.caption2, design: .serif))
                    .foregroundStyle(InkPalette.cinnabar)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
            }
        }
        .overlay { Rectangle().stroke(InkPalette.ink, lineWidth: 1) }
    }

    private var detail: String {
        switch health.accessState {
        case .unavailable: return "Not available on this device"
        case .notConnected: return "Save sessions and read your latest weight"
        case .denied: return "Workout access is disabled"
        case .connected:
            let weight = health.latestBodyMassKilograms.map {
                " · \(WorkoutValueFormatter.weight($0)) kg"
            } ?? ""
            let queued = healthSync.queuedJobCount > 0
                ? " · \(healthSync.queuedJobCount) pending"
                : ""
            return "Connected\(weight)\(queued)"
        }
    }

    private var actionTitle: String {
        switch health.accessState {
        case .unavailable: "UNAVAILABLE"
        case .notConnected: "CONNECT"
        case .denied: "SETTINGS"
        case .connected: "REFRESH"
        }
    }

    private func performAction() {
        switch health.accessState {
        case .notConnected, .connected:
            Task { await health.requestAccess() }
        case .denied:
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        case .unavailable:
            break
        }
    }
}

private struct RoutineCard: View {
    let routine: RoutineTemplate
    var isRecommended = false
    var lastCompleted: Date?

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(routine.id)
                    .font(.system(size: 58, weight: .regular, design: .serif))
                    .tracking(-2)
                    .foregroundStyle(isRecommended ? InkPalette.cinnabar : InkPalette.ink)
                Text(routine.focus.replacingOccurrences(of: " · ", with: ", "))
                    .font(.system(size: 15, weight: .medium, design: .serif))
                    .foregroundStyle(InkPalette.softInk.opacity(0.82))
                    .lineLimit(2)
                Text(lastCompletedText)
                    .font(.system(.caption, design: .serif))
                    .foregroundStyle(InkPalette.softInk.opacity(0.72))
                    .monospacedDigit()
                HStack(spacing: 6) {
                    Text("VIEW ROUTINE")
                    Image(systemName: "arrow.right")
                }
                .font(.system(.caption2, design: .serif, weight: .semibold))
                .tracking(1.1)
                .foregroundStyle(InkPalette.cinnabar)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            DemonstrationImage(assetName: routine.exercises[0].assetName, outlined: false)
                .frame(width: 136, height: 144)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .frame(minHeight: 174)
        .background(InkPalette.raisedPaper)
        .overlay {
            Rectangle().stroke(InkPalette.bronze.opacity(isRecommended ? 0.9 : 0.52), lineWidth: 1)
        }
        .overlay(alignment: .top) { if isRecommended { ClassicalRule() } }
        .shadow(color: InkPalette.ink.opacity(0.055), radius: 8, y: 3)
        .contentShape(Rectangle())
    }

    private var lastCompletedText: String {
        guard let lastCompleted else { return "No previous session" }
        return "Last · \(lastCompleted.formatted(.dateTime.day().month(.abbreviated)))"
    }
}
