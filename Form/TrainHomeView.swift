import Foundation
import SwiftData
import SwiftUI
import UIKit

struct RoutineListView: View {
    @AppStorage("progression-load-increment") private var loadIncrement = 2.5
    @AppStorage("keep-screen-awake") private var keepScreenAwake = true
    @StateObject private var health = HealthKitService.shared
    @StateObject private var healthSync = HealthSyncCoordinator.shared
    @State private var showingSettings = false

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Spacer()
                        Button("settings") { showingSettings = true }
                            .font(.system(.subheadline, design: .default))
                            .foregroundStyle(InkPalette.softInk)
                            .frame(minWidth: 64, minHeight: 44, alignment: .trailing)
                            .buttonStyle(PressableButtonStyle())
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
                            Text("settings")
                                .font(.system(.title3, design: .default))
                                .foregroundStyle(InkPalette.ink)
                            Spacer()
                            Button("Done") { showingSettings = false }
                                .font(AtelierType.script(17))
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
    }

    private var settings: some View {
        VStack(spacing: 0) {
            FieldSectionTitle(title: "preferences")
            HStack {
                Text("load increment")
                    .font(AtelierType.script(17))
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

            Toggle(isOn: $keepScreenAwake) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("KEEP SCREEN AWAKE")
                        .font(AtelierType.script(17))
                        .textCase(.lowercase)
                        .foregroundStyle(InkPalette.softInk)
                    Text("While a session is in progress")
                        .font(.system(.caption, design: .default))
                        .foregroundStyle(InkPalette.softInk.opacity(0.76))
                }
            }
            .tint(InkPalette.verdigris)
            .frame(minHeight: 58)
            .padding(.horizontal, 12)
        }
    }

}

struct CloudIntegrationSection: View {
    var body: some View {
        VStack(spacing: 0) {
            FieldSectionTitle(title: "iCloud")
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

struct HealthIntegrationSection: View {
    @ObservedObject var health: HealthKitService
    @ObservedObject var healthSync: HealthSyncCoordinator

    var body: some View {
        VStack(spacing: 0) {
            FieldSectionTitle(title: "Apple Health")
            HStack(alignment: .center, spacing: 14) {
                Text(detail)
                    .font(.system(.caption, design: .default))
                    .foregroundStyle(InkPalette.softInk.opacity(0.8))
                Spacer(minLength: 12)
                Button(actionTitle) { performAction() }
                    .font(AtelierType.script(14))
                    .foregroundStyle(InkPalette.plum)
                    .frame(minWidth: 72, minHeight: 44, alignment: .trailing)
                    .buttonStyle(PressableButtonStyle())
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
    @State private var showingSettings = false

    private var next: RoutineTemplate {
        snapshot?.resolvedRoutine ?? FormRoutine.next(after: history.first(where: {
            FormRoutine.sessions.map(\.id).contains($0.routineID)
        })?.routineID)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("form.").font(AtelierType.script(30))
                    Spacer()
                    Button { showingSettings = true } label: {
                        Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44)
                    }.accessibilityLabel("Settings")
                }
                Text("a little\nmovement.").font(AtelierType.script(46)).lineSpacing(-5)
                Text("good to see you.").font(AtelierType.script(20)).foregroundStyle(InkPalette.softInk)
                PaperVignette(name: "arrive", height: 220)
                Text(snapshot == nil ? "UP NEXT" : "PICK UP WHERE YOU LEFT OFF")
                    .font(.caption2).tracking(2).foregroundStyle(InkPalette.softInk)
                Text("A full-body session").font(.title3)
                Text(next.focus).font(.subheadline).foregroundStyle(InkPalette.softInk)
                Text("About 45 minutes, all together.").font(.caption).foregroundStyle(InkPalette.softInk)
                InkPrimaryButton(title: snapshot == nil ? "Start session →" : "Resume session →") {
                    presentedRoutine = next
                }.padding(.top, 12)
                Button("View routine") { showingRoutine = true }
                    .font(AtelierType.script(20)).frame(maxWidth: .infinity, minHeight: 44)
            }.padding(.horizontal, 28).padding(.bottom, 20)
        }
        .background(PaperBackground())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { snapshot = ActiveWorkoutStore.load() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { snapshot = ActiveWorkoutStore.load() }
        }
        .fullScreenCover(item: $presentedRoutine, onDismiss: { snapshot = ActiveWorkoutStore.load() }) { routine in
            ActiveWorkoutView(routine: routine, snapshot: snapshot)
        }
        .sheet(isPresented: $showingRoutine) {
            NavigationStack {
                List {
                    ForEach(FormRoutine.sessions) { routine in
                        Section(routine.name) {
                            ForEach(routine.exercises) { exercise in
                                HStack {
                                    DemonstrationImage(assetName: exercise.id).frame(width: 64, height: 56)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(exercise.name)
                                        Text(exercise.targetText + (exercise.id == "reverse-lunge" ? " / side" : ""))
                                            .font(.caption).foregroundStyle(InkPalette.softInk)
                                    }
                                }
                            }
                            Text("Then, a 15 min treadmill walk.").font(AtelierType.script(20))
                        }
                    }
                }.scrollContentBackground(.hidden).background(.white)
                    .navigationTitle("The routine").navigationBarTitleDisplayMode(.inline)
                    .toolbar { Button("Done") { showingRoutine = false } }
            }
        }
        .sheet(isPresented: $showingSettings) { FormSettingsView() }
    }
}

struct FormSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("progression-load-increment") private var loadIncrement = 2.5
    @AppStorage("keep-screen-awake") private var keepScreenAwake = true
    @StateObject private var health = HealthKitService.shared
    @StateObject private var sync = HealthSyncCoordinator.shared
    var body: some View {
        NavigationStack {
            Form {
                Section("Preferences") {
                    Picker("Load increment", selection: $loadIncrement) {
                        ForEach([1.0, 1.25, 2, 2.5, 5], id: \.self) { value in
                            Text("\(WorkoutValueFormatter.decimal(value)) kg").tag(value)
                        }
                    }
                    Toggle("Keep screen awake during sessions", isOn: $keepScreenAwake)
                }
                CloudIntegrationSection()
                HealthIntegrationSection(health: health, healthSync: sync)
            }.scrollContentBackground(.hidden).background(.white)
                .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Done") { dismiss() } }
        }
    }
}
