import Foundation
import SwiftData
import SwiftUI
import UIKit

struct RoutineListView: View {
    @State private var showingSettings = false

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Spacer()
                        CounterweightIconButton(symbol: "slider.horizontal.3", label: "Settings") { showingSettings = true }
                    }
                    .padding(.bottom, 28)

                    LazyVStack(spacing: 0) {
                        ForEach(WorkoutCatalog.routines) { routine in
                            NavigationLink(value: routine) {
                                RoutineThreadRow(routine: routine)
                            }
                            .buttonStyle(PressableButtonStyle())
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 36)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingSettings) { FormSettingsView() }
    }
}


struct CloudIntegrationSection: View {
    var body: some View {
        VStack(spacing: 0) {
            FieldSectionTitle(title: "Storage")
            HStack(spacing: 14) {
                Text(detail)
                    .font(.system(.caption, design: .default))
                    .foregroundStyle(InkPalette.softInk.opacity(0.8))
                Spacer()
                Text(status.lowercased())
                    .font(AtelierType.script(14))
                    .foregroundStyle(InkPalette.plum)
            }
            .padding(.horizontal, 7)
            .frame(minHeight: 58)
        }
    }

    private var detail: String {
        switch AppModelContainer.storageMode {
        case .iCloud: "Workout history syncs through your private iCloud database"
        case .localFallback: "Workouts are stored on this iPhone. Use a backup to move them to another device."
        }
    }

    private var status: String {
        switch AppModelContainer.storageMode {
        case .iCloud: "SYNCING"
        case .localFallback: "LOCAL"
        }
    }
}

struct HealthIntegrationSection: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var workouts: [WorkoutRecord]
    @Environment(\.dynamicTypeSize) private var typeSize
    @ObservedObject var health: HealthKitService
    @ObservedObject var healthSync: HealthSyncCoordinator

    var body: some View {
        VStack(spacing: 0) {
            FieldSectionTitle(title: "Apple Health")
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14)) : AnyLayout(HStackLayout(spacing: 14))
            layout {
                Text(detail)
                    .font(.system(.caption, design: .default))
                    .foregroundStyle(InkPalette.softInk.opacity(0.8))
                if !typeSize.isAccessibilitySize { Spacer(minLength: 12) }
                CounterweightControl(title: actionTitle, symbol: "heart", action: performAction)
                    .disabled(health.accessState == .unavailable)
            }
            .padding(.horizontal, 7)
            .frame(minHeight: 58)

            if let errorMessage = health.errorMessage ?? healthSync.lastError {
                Text(errorMessage)
                    .font(.system(.caption2, design: .default))
                    .foregroundStyle(InkPalette.cinnabar)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
            }
        }
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
        case .unavailable: "Unavailable"
        case .notConnected: "Connect"
        case .denied: "Settings"
        case .connected: "Refresh"
        }
    }

    private func performAction() {
        switch health.accessState {
        case .notConnected:
            Task { await health.requestAccess() }
        case .connected:
            Task {
                await health.refresh()
                await healthSync.retryPending(in: modelContext, workouts: workouts)
            }
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

    var body: some View {
        Text(routine.name)
            .font(.system(size: 25, weight: .regular, design: .default))
            .foregroundStyle(InkPalette.ink)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .center)
        .contentShape(Rectangle())
    }
}


struct TodayView: View {
    @Query(sort: \WorkoutRecord.date, order: .reverse) private var history: [WorkoutRecord]
    @Environment(\.scenePhase) private var scenePhase
    @State private var snapshot: ActiveWorkoutSnapshot?
    @State private var presentedRoutine: RoutineTemplate?
    @State private var showingRoutine = false
    @State private var showingDiscardConfirmation = false
    @State private var discardAfterSheet = false
    @State private var showingSettings = false

    @State private var recoveryError: String?

    @Environment(\.dynamicTypeSize) private var typeSize

    private var illustration: String {
        if recoveryError != nil { return "pages" }
        if snapshot != nil { return "pause" }
        if let last = history.first, Calendar.current.isDateInToday(last.date) { return "finished" }
        return "arrive"
    }

    private var activeProgress: String? {
        guard let snapshot else { return nil }
        let sets = snapshot.exercises.reduce(0) { $0 + $1.sets.filter(\.completed).count }
        var parts = ["\(sets) set\(sets == 1 ? "" : "s") recorded"]
        if !snapshot.cardio.isEmpty {
            parts.append("\(snapshot.cardio.count) cardio entr\(snapshot.cardio.count == 1 ? "y" : "ies")")
        }
        if snapshot.timedWalk != nil { parts.append("Walk in progress") }
        return parts.joined(separator: " · ")
    }

    private var next: RoutineTemplate {
        snapshot?.resolvedRoutine ?? FormRoutine.next(after: history.first(where: {
            FormRoutine.sessions.map(\.id).contains($0.routineID)
        })?.routineID)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Today").font(.title2.weight(.bold)).accessibilityAddTraits(.isHeader)
                if let recoveryError {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Session needs attention").font(.headline)
                        Text(recoveryError).font(.subheadline)
                        CounterweightControl(title: "Retry", symbol: "arrow.clockwise", action: reloadSession)
                    }
                }
                CounterweightFigure(resting: snapshot != nil)
                    .frame(width: 172, height: 172).frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                VStack(spacing: 12) {
                    Text(next.name).font(.title3.weight(.semibold)).accessibilityAddTraits(.isHeader)
                    if let snapshot, let activeProgress {
                        Text(activeProgress).font(.caption).foregroundStyle(InkPalette.softInk)
                        Text("Started " + snapshot.startedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption).foregroundStyle(InkPalette.softInk)
                    } else {
                        Text("\(next.exercises.count) exercises · optional walk").font(.caption).foregroundStyle(InkPalette.softInk)
                    }
                    Button {
                        reloadSession()
                        if recoveryError == nil { presentedRoutine = next }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "arrow.right").frame(width: 50, height: 50)
                                .foregroundStyle(InkPalette.paper).background(InkPalette.ink, in: Circle())
                            Text(snapshot == nil ? "Start workout" : "Resume workout").font(.subheadline.weight(.semibold))
                        }.padding(.vertical, 16).frame(maxWidth: .infinity)
                    }.buttonStyle(PressableButtonStyle()).disabled(recoveryError != nil)
                    CounterweightControl(title: "View routine", symbol: "list.bullet") { showingRoutine = true }
                    if snapshot != nil || recoveryError != nil {
                        CounterweightControl(title: "Discard workout", symbol: "trash") { showingDiscardConfirmation = true }
                    }
                }.frame(maxWidth: .infinity).multilineTextAlignment(.center)
                if let last = history.first {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last workout").font(.caption).foregroundStyle(InkPalette.softInk)
                        NavigationLink(value: last) { HistoryCard(workout: last) }
                            .buttonStyle(PressableButtonStyle())
                    }.padding(.top, 24)
                }
            }.padding(.horizontal, CounterweightLayout.pageInset).padding(.top, 24).padding(.bottom, 32)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            CounterweightHeader {
                CounterweightIconButton(symbol: "slider.horizontal.3", label: "Settings") { showingSettings = true }
            }
        }
        .background(PaperBackground())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingDiscardConfirmation, onDismiss: {
            guard discardAfterSheet else { return }
            discardAfterSheet = false
            do { try ActiveWorkoutStore.clearChecked() }
            catch { recoveryError = "Couldn’t discard the saved session. Try again."; return }
            recoveryError = nil
            snapshot = nil
            RestFeedbackService.shared.cancel()
            Task { await WorkoutLiveActivityController.forceEnd() }
        }) {
            CounterweightDiscardSheet(discard: {
                discardAfterSheet = true; showingDiscardConfirmation = false
            }, keep: { showingDiscardConfirmation = false })
        }
        .onAppear { reloadSession() }
        .onChange(of: history.map(\.persistentModelID)) { _, _ in
            reloadSession()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { reloadSession() }
        }
        .fullScreenCover(item: $presentedRoutine, onDismiss: { reloadSession() }) { routine in
            ActiveWorkoutView(routine: routine, snapshot: snapshot)
        }
        .sheet(isPresented: $showingRoutine) {
            CounterweightSheet(title: "The routine") {
                ForEach(FormRoutine.sessions) { routine in
                    Text(routine.name).font(.headline).accessibilityAddTraits(.isHeader)
                    ForEach(routine.exercises) { exercise in
                        HStack(spacing: 16) {
                            DemonstrationImage(assetName: exercise.id).frame(width: 54, height: 54)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(exercise.name).font(.subheadline)
                                Text(exercise.targetText + (exercise.id == "reverse-lunge" ? " / side" : ""))
                                    .font(.caption).foregroundStyle(InkPalette.softInk)
                            }
                        }
                    }
                    Text("Optional: a 15 min treadmill walk.").font(.caption).foregroundStyle(InkPalette.softInk)
                    InkDivider()
                }
            }
        }
        .sheet(isPresented: $showingSettings) { FormSettingsView() }
    }

    private func reloadSession() {
        do {
            let saved = try ActiveWorkoutStore.loadChecked(completedWorkouts: history)
            guard saved == nil || saved?.resolvedRoutine != nil else {
                throw ActiveSessionStore.RecoveryError.unreadable
            }
            snapshot = saved
            recoveryError = nil
        } catch {
            snapshot = nil
            recoveryError = error.localizedDescription
        }
    }
}

struct FormSettingsView: View {
    @AppStorage("progression-load-increment") private var loadIncrement = 2.5
    @AppStorage("keep-screen-awake") private var keepScreenAwake = true
    @StateObject private var health = HealthKitService.shared
    @StateObject private var sync = HealthSyncCoordinator.shared

    var body: some View {
        CounterweightSheet(title: "Settings") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Load increment").font(.subheadline.weight(.medium))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 88))], spacing: 8) {
                    ForEach([1.0, 1.25, 2, 2.5, 5], id: \.self) { value in
                        CounterweightChoice(title: "\(WorkoutValueFormatter.decimal(value)) kg", selected: loadIncrement == value) {
                            loadIncrement = value
                        }.accessibilityLabel("Load increment, \(WorkoutValueFormatter.decimal(value)) kilograms")
                    }
                }
            }
            InkDivider()
            Toggle(isOn: $keepScreenAwake) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Keep screen awake").font(.subheadline.weight(.medium))
                    Text("During a workout").font(.caption).foregroundStyle(InkPalette.softInk)
                }
            }.tint(InkPalette.ink)
            InkDivider()
            CloudIntegrationSection()
            InkDivider()
            HealthIntegrationSection(health: health, healthSync: sync)
        }
        .task {
            await health.refresh()
            await sync.refreshPendingCount()
        }
    }
}
