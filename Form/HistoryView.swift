import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutRecord.date, order: .reverse) private var workouts: [WorkoutRecord]
    @State private var showingSettings = false
    @State private var saveErrorMessage: String?
    @State private var selectedSection: HistorySection = .sessions
    @State private var showingExerciseIndex = false
    @State private var showingBackupImporter = false
    @State private var restoreMessage: String?
    let openWorkout: (WorkoutRecord) -> Void

    var body: some View {
        ZStack {
            PaperBackground()
            if workouts.isEmpty {
                VStack(spacing: 0) {
                    EmptyHistoryView(showRestore: { showingBackupImporter = true })
                        .frame(maxHeight: .infinity)
                }
            } else {
                List {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("little by little.").font(AtelierType.script(40))
                        Text("a few days of showing up.").font(AtelierType.script(20)).foregroundStyle(InkPalette.softInk)
                    }.historyRow(top: 12, bottom: 12)
                    if selectedSection == .overview {
                        HistoryWeeklySummary(workouts: workouts)
                            .historyRow(bottom: 18)
                        HistoryConsistencyView(workouts: workouts)
                            .historyRow(bottom: 18)
                        CoachingReportShareRow(workouts: workouts)
                            .historyRow(bottom: 8)
                        BackupManagementView(
                            workouts: workouts,
                            restore: { showingBackupImporter = true }
                        )
                        .historyRow(bottom: 28)
                    } else {
                        Section {
                            ForEach(workouts) { workout in
                                Button { openWorkout(workout) } label: {
                                    HistoryCard(workout: workout)
                                }
                                .buttonStyle(PressableButtonStyle())
                                .historyRow()
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) { delete(workout) } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .tint(InkPalette.cinnabar)
                                }
                                .contextMenu {
                                    Button("Delete session", role: .destructive) {
                                        delete(workout)
                                    }
                                }
                            }
                        }
                        .listRowBackground(Color.clear)
                        PaperVignette(name: "pages", height: 190).historyRow(bottom: 12)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .contentMargins(.bottom, 18, for: .scrollContent)
            }
        }
        .safeAreaInset(edge: .top) {
            HStack {
                Text("form.").font(AtelierType.script(30))
                Spacer()
                Menu {
                    Button("Sessions") { selectedSection = .sessions }
                    Button("Overview") { selectedSection = .overview }
                    Button("Exercise progress") { showingExerciseIndex = true }
                    Button("Restore a backup") { showingBackupImporter = true }
                } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                    .accessibilityLabel("History options")
                Button { showingSettings = true } label: {
                    Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44)
                }.accessibilityLabel("Settings")
            }.padding(.horizontal, 28).background(.white)
        }
        .sheet(isPresented: $showingSettings) { FormSettingsView() }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingExerciseIndex) { ExerciseIndexView() }
        .fileImporter(
            isPresented: $showingBackupImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            restore(result)
        }
        .alert("Form record", isPresented: Binding(
            get: { saveErrorMessage != nil || restoreMessage != nil },
            set: {
                if !$0 {
                    saveErrorMessage = nil
                    restoreMessage = nil
                }
            }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveErrorMessage ?? restoreMessage ?? "")
        }
    }

    private func delete(_ workout: WorkoutRecord) {
        let identifier = workout.healthSyncIdentifier
        let healthUUID = workout.healthKitWorkoutUUID
        withAnimation(.easeOut(duration: 0.2)) {
            modelContext.delete(workout)
        }
        do {
            try modelContext.save()
            Task {
                await HealthSyncCoordinator.shared.enqueueDelete(
                    recordIdentifier: identifier,
                    workoutUUID: healthUUID
                )
            }
        } catch {
            modelContext.rollback()
            saveErrorMessage = "The session remains in the record. Try again."
        }
    }

    private func restore(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            let count = try WorkoutBackup.restore(
                data: Data(contentsOf: url),
                into: modelContext
            )
            restoreMessage = count == 0
                ? "This backup contains no new sessions."
                : "Restored \(count) session\(count == 1 ? "" : "s")."
        } catch {
            restoreMessage = "The backup could not be restored. \(error.localizedDescription)"
        }
    }
}

private extension View {
    func historyRow(top: CGFloat = 0, bottom: CGFloat = 0) -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: top, leading: 20, bottom: bottom, trailing: 20))
    }
}

private enum HistorySection: String, CaseIterable, Identifiable {
    case sessions
    case overview
    var id: String { rawValue }
    var title: String { rawValue }
}

private struct HistorySectionControl: View {
    @Binding var selection: HistorySection

    var body: some View {
        HStack(spacing: 30) {
            ForEach(HistorySection.allCases) { section in
                Button { selection = section } label: {
                    Text(section.title)
                        .font(.system(.subheadline, design: .default))
                        .foregroundStyle(selection == section
                            ? InkPalette.ink
                            : InkPalette.softInk.opacity(0.68))
                        .frame(minWidth: 84, minHeight: 46)
                        .overlay(alignment: .bottom) {
                            if selection == section {
                                InkDivider()
                                    .frame(width: 62)
                                    .colorMultiply(InkPalette.mineral)
                            }
                        }
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityAddTraits(selection == section ? .isSelected : [])
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 7)
    }
}
