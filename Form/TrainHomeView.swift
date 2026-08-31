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
    @State private var showingSettings = false

    private var nextRoutine: RoutineTemplate {
        WorkoutCatalog.nextRoutine(after: workouts.first)
    }

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Training")
                            .font(AtelierType.script(34))
                            .foregroundStyle(InkPalette.ink)
                        Spacer()
                        Button("Settings") { showingSettings = true }
                            .font(.system(.subheadline, design: .serif))
                            .foregroundStyle(InkPalette.ink)
                            .frame(minWidth: 64, minHeight: 44, alignment: .trailing)
                            .buttonStyle(PressableButtonStyle())
                    }
                    .padding(.bottom, 16)

                    InkDivider()
                        .opacity(0.5)
                        .padding(.bottom, 10)

                    LazyVStack(spacing: 0) {
                        ForEach(WorkoutCatalog.routines) { routine in
                            NavigationLink(value: routine) {
                                RoutineThreadRow(
                                    routine: routine,
                                    isNext: routine.id == nextRoutine.id,
                                    lastCompleted: lastCompleted(routine)
                                )
                            }
                            .buttonStyle(PressableButtonStyle())
                        }
                    }
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(InkPalette.bronze.opacity(0.62))
                            .frame(width: 1)
                            .padding(.leading, 16)
                            .padding(.vertical, 38)
                            .accessibilityHidden(true)
                    }

                    if let resumeRoutine {
                        Button { showingResume = true } label: {
                            HStack(alignment: .center, spacing: 16) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("\(resumeRoutine.name) remains open")
                                        .font(.system(.body, design: .serif))
                                        .foregroundStyle(InkPalette.ink)
                                    Text(resumeDetail)
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(InkPalette.softInk)
                                }
                                Spacer(minLength: 8)
                                Text("Resume")
                                    .font(.system(.subheadline, design: .serif))
                                    .foregroundStyle(InkPalette.mineral)
                                    .frame(minWidth: 58, minHeight: 44, alignment: .trailing)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(InkPalette.raisedPaper.opacity(0.74))
                            .shadow(color: InkPalette.ink.opacity(0.035), radius: 5, y: 2)
                        }
                        .buttonStyle(PressableButtonStyle())
                        .padding(.top, 18)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 36)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { resumeSnapshot = ActiveWorkoutStore.load() }
        .task {
            await health.refresh()
            await healthSync.refreshPendingCount()
        }
        .sheet(isPresented: $showingSettings) {
            ZStack {
                PaperBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Settings")
                                .font(AtelierType.script(32))
                                .foregroundStyle(InkPalette.ink)
                            Spacer()
                            Button("Done") { showingSettings = false }
                                .font(.system(.body, design: .serif))
                                .foregroundStyle(InkPalette.mineral)
                                .frame(minWidth: 50, minHeight: 44, alignment: .trailing)
                                .buttonStyle(PressableButtonStyle())
                        }
                        .padding(.bottom, 6)

                        settings
                        CloudIntegrationSection()
                        HealthIntegrationSection(health: health, healthSync: healthSync)
                    }
                    .padding(20)
                }
            }
            .presentationDetents([.medium, .large])
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
        case .notConnected:
            Task { await health.requestAccess() }
        case .connected:
            Task { await health.refresh() }
        case .denied:
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        case .unavailable:
            break
        }
    }
}

private struct RoutineThreadRow: View {
    let routine: RoutineTemplate
    let isNext: Bool
    var lastCompleted: Date?

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(InkPalette.paper)
                    .frame(width: 18, height: 18)
                if isNext {
                    Circle()
                        .trim(from: 0.08, to: 0.79)
                        .stroke(InkPalette.mineral, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-40))
                        .frame(width: 22, height: 22)
                } else {
                    Circle()
                        .stroke(InkPalette.softInk.opacity(0.75), lineWidth: 1)
                        .frame(width: 12, height: 12)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                if isNext {
                    Text("NEXT")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .tracking(1.8)
                        .foregroundStyle(InkPalette.mineral)
                }
                Text(routine.name)
                    .font(AtelierType.script(25))
                    .foregroundStyle(isNext ? InkPalette.mineral : InkPalette.ink)
                Text(lastCompletedText)
                    .font(.system(.caption2, design: .serif))
                    .foregroundStyle(InkPalette.softInk.opacity(0.78))
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            DemonstrationImage(assetName: routine.exercises[0].assetName, outlined: false)
                .frame(width: 112, height: 102)
                .rotationEffect(.degrees(isNext ? 0.8 : -0.45))
        }
        .padding(.leading, 7)
        .padding(.trailing, 2)
        .padding(.vertical, 10)
        .frame(minHeight: 122)
        .background {
            if isNext {
                InkPalette.mineral.opacity(0.065)
            }
        }
        .overlay(alignment: .leading) {
            if isNext {
                Rectangle().fill(InkPalette.mineral).frame(width: 2)
            }
        }
        .overlay(alignment: .bottom) { InkDivider().opacity(0.38) }
        .contentShape(Rectangle())
    }

    private var lastCompletedText: String {
        guard let lastCompleted else { return "No previous session" }
        return "Last · \(lastCompleted.formatted(.dateTime.day().month(.abbreviated)))"
    }
}
