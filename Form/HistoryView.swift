import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutRecord.date, order: .reverse) private var workouts: [WorkoutRecord]
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
                    HistoryHeader()
                    EmptyHistoryView(showRestore: { showingBackupImporter = true })
                        .frame(maxHeight: .infinity)
                }
            } else {
                List {
                    HistoryHeader()
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())

                    HistorySectionControl(selection: $selectedSection)
                        .historyRow(bottom: 4)

                    Button { showingExerciseIndex = true } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(InkPalette.softInk)
                            Text("Find exercise progress")
                                .font(AtelierType.script(20))
                                .foregroundStyle(InkPalette.ink)
                            Spacer()
                        }
                        .padding(.horizontal, 7)
                        .frame(minHeight: 58)
                        .overlay(alignment: .bottom) { InkDivider().opacity(0.38) }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableButtonStyle())
                    .historyRow(bottom: 16)

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
                        .overlay(alignment: .leading) {
                            FieldThread()
                                .padding(.leading, 36)
                                .padding(.vertical, 34)
                                .accessibilityHidden(true)
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .contentMargins(.bottom, 18, for: .scrollContent)
            }
        }
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

private struct HistoryHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("record")
                .font(AtelierType.script(34))
                .foregroundStyle(InkPalette.ink)
            InkDivider().opacity(0.5)
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
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
                        .font(AtelierType.script(18))
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
        .overlay(alignment: .bottom) { InkDivider().opacity(0.38) }
    }
}
