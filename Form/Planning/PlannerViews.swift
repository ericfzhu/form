import SwiftData
import SwiftUI

struct PlanHomeView: View {
    @EnvironmentObject private var planner: PlannerStore
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \WorkoutRecord.date, order: .reverse) private var history: [WorkoutRecord]
    @State private var active: ActiveWorkoutSnapshot?
    @State private var resume = false
    @State private var preferences = false
    let openGym: () -> Void

    private var nextIndex: Int {
        guard let last = history.first(where: { record in record.hasTrainingData && planner.sessions.contains { $0.id == record.routineID } }),
              let index = planner.sessions.firstIndex(where: { $0.id == last.routineID }) else { return 0 }
        return (index + 1) % planner.sessions.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack(alignment: .firstTextBaseline) {
                    Text("form.").font(.system(size: 40, weight: .medium, design: .rounded)).tracking(-2)
                    Spacer()
                    Button { preferences = true } label: {
                        Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44)
                    }.accessibilityLabel("Preferences and integrations")
                }
                if let active, active.resolvedRoutine != nil {
                    Button { resume = true } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Pick up where you left off").font(.headline)
                                Text(active.resolvedRoutine?.name ?? "Your session").font(.subheadline)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }.padding(20).background(InkPalette.salvia.opacity(0.3), in: RoundedRectangle(cornerRadius: 18))
                    }.buttonStyle(.plain)
                }
                if !planner.profile.configured {
                    introduction
                } else if PlanningCatalog.exercises.isEmpty {
                    ContentUnavailableView("Exercise library unavailable", systemImage: "exclamationmark.triangle", description: Text("Please reopen the app. Your gym and history are still saved."))
                } else {
                    plan
                }
            }
            .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 32)
        }
        .background(InkPalette.paper)
        .toolbar(.hidden, for: .navigationBar)
        .task { active = ActiveWorkoutStore.load() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { active = ActiveWorkoutStore.load() } }
        .sheet(isPresented: $preferences) {
            NavigationStack {
                RoutineListView().toolbar(.visible, for: .navigationBar)
                    .navigationTitle("Original routines & settings")
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { preferences = false } } }
                    .navigationDestination(for: RoutineTemplate.self) { RoutineDetailView(routine: $0) }
                    .navigationDestination(for: ExerciseTemplate.self) { ExerciseProgressView(exercise: $0) }
            }
        }
        .fullScreenCover(isPresented: $resume, onDismiss: { active = ActiveWorkoutStore.load() }) {
            if let active, let routine = active.resolvedRoutine { ActiveWorkoutView(routine: routine, snapshot: active) }
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("A little plan.\nA good session.").font(.system(size: 38, weight: .medium)).tracking(-1.4)
                .fixedSize(horizontal: false, vertical: true)
            Image("form-planner").resizable().scaledToFit().frame(maxHeight: 230).accessibilityHidden(true)
            Text("Start with what’s in your gym. We’ll put together a rotation you can review, change, and make your own.")
                .font(.body).foregroundStyle(InkPalette.softInk)
            InkPrimaryButton(title: "Set up my gym", action: openGym)
            Text("Your equipment. Your pace.").font(.system(.title3, design: .rounded))
        }
    }

    private var plan: some View {
        VStack(alignment: .leading, spacing: 24) {
            Button(action: openGym) {
                HStack {
                    Label(planner.profile.name.isEmpty ? "My gym" : planner.profile.name, systemImage: "building.2")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }.font(.subheadline)
            }.buttonStyle(.plain)
            let next = planner.sessions[nextIndex]
            NavigationLink(value: next.routine) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("UP NEXT").font(.caption.weight(.semibold)).tracking(2)
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(next.name).font(.system(size: 34, weight: .medium)).tracking(-1)
                            Text(next.subtitle).font(.body)
                            Text("\(next.movements.count) movements · ~\(next.estimatedMinutes) min")
                                .font(.subheadline).foregroundStyle(InkPalette.softInk)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "arrow.up.right").font(.title2)
                    }
                    Rectangle().fill(InkPalette.ink.opacity(0.16)).frame(height: 1)
                    Text("Make it a good one.").font(.system(.title3, design: .rounded))
                }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
                    .background(InkPalette.salvia.opacity(0.4), in: RoundedRectangle(cornerRadius: 22))
            }.buttonStyle(.plain)
            HStack {
                Text("Your rotation").font(.title2.weight(.medium))
                Spacer()
                Text("\(planner.profile.sessionsPerWeek) / week").font(.subheadline).foregroundStyle(InkPalette.softInk)
            }
            VStack(spacing: 0) {
                ForEach(planner.sessions) { session in
                    NavigationLink(value: session.routine) {
                        HStack(spacing: 18) {
                            Text(String(session.id.suffix(1))).font(.title2).frame(width: 32)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(session.subtitle).font(.headline)
                                Text("\(session.movements.count) movements · ~\(session.estimatedMinutes) min").font(.subheadline).foregroundStyle(InkPalette.softInk)
                                if !session.missing.isEmpty {
                                    Text("Review: \(session.missing.map(\.title).joined(separator: ", ")) unavailable")
                                        .font(.caption).foregroundStyle(InkPalette.softInk)
                                }
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.caption)
                        }.padding(.vertical, 20)
                    }.buttonStyle(.plain)
                    InkDivider()
                }
            }
            Text("Follow the rotation on the days that suit you. The next session advances after you save a workout.")
                .font(.subheadline).foregroundStyle(InkPalette.softInk)
            Image("form-planner").resizable().scaledToFit().frame(height: 160).frame(maxWidth: .infinity).accessibilityHidden(true)
        }
    }
}

struct GymProfileView: View {
    @EnvironmentObject private var planner: PlannerStore
    @State private var draft = GymProfile()
    @State private var saved = false
    let done: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("My gym.").font(.system(size: 38, weight: .medium)).tracking(-1.5)
                Text("A plan starts with what’s here.").font(.system(.title3, design: .rounded)).foregroundStyle(InkPalette.softInk)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Gym name").font(.subheadline.weight(.medium))
                    TextField("My gym", text: $draft.name).textFieldStyle(.roundedBorder).submitLabel(.done)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Equipment").font(.title2.weight(.medium))
                    Text("Select what you can use. Bodyweight movements are always included.").font(.subheadline).foregroundStyle(InkPalette.softInk)
                    ForEach(GymEquipment.allCases.filter { !$0.isCardio }) { item in
                        Toggle(item.title, isOn: Binding(
                            get: { draft.equipment.contains(item) },
                            set: { selected in
                                if selected { draft.equipment.insert(item) } else { draft.equipment.remove(item) }
                                saved = false
                            }
                        )).tint(InkPalette.ink).padding(.vertical, 5)
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Cardio equipment").font(.title2.weight(.medium))
                    ForEach(GymEquipment.allCases.filter(\.isCardio)) { item in
                        Toggle(item.title, isOn: Binding(
                            get: { draft.equipment.contains(item) },
                            set: { if $0 { draft.equipment.insert(item) } else { draft.equipment.remove(item) } }
                        )).tint(InkPalette.ink).padding(.vertical, 5)
                    }
                }
                InkDivider()
                VStack(alignment: .leading, spacing: 20) {
                    Text("Your rhythm").font(.title2.weight(.medium))
                    Picker("Focus", selection: $draft.focus) {
                        ForEach(TrainingFocus.allCases) { focus in Text(focus.title).tag(focus) }
                    }.pickerStyle(.menu)
                    Stepper("\(draft.sessionsPerWeek) sessions / week", value: $draft.sessionsPerWeek, in: 2...4)
                    Picker("Time per session", selection: $draft.minutes) {
                        ForEach([30, 45, 60], id: \.self) { Text("\($0) min").tag($0) }
                    }.pickerStyle(.segmented)
                    Text("Time is an estimate. You choose your loads and can adjust sets as you train.")
                        .font(.subheadline).foregroundStyle(InkPalette.softInk)
                }
                if WorkoutPlanner.available(in: draft, pattern: .pull).isEmpty {
                    Label("No pulling movement fits this equipment yet. Add a barbell, pulley, row station, pulldown, or dumbbells with a bench to include one.", systemImage: "info.circle")
                        .font(.subheadline).foregroundStyle(InkPalette.softInk).fixedSize(horizontal: false, vertical: true)
                }
                if let message = planner.storageMessage { Text(message).foregroundStyle(.red) }
                InkPrimaryButton(title: planner.profile.configured ? "Save gym & update plan" : "Make my plan") {
                    draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    if draft.name.isEmpty { draft.name = "My gym" }
                    draft.configured = true
                    planner.profile = draft
                    saved = true
                    done()
                }
                if saved { Text("Gym saved on this device.").font(.subheadline) }
                Text("Changes affect future sessions. A workout already in progress keeps its original movements.")
                    .font(.footnote).foregroundStyle(InkPalette.softInk)
            }.padding(24)
        }
        .background(InkPalette.paper)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { draft = planner.profile }
    }
}
