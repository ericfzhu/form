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
                    RawScreenTitle(index: "02", title: "Record", detail: "12 WEEKS")
                    EmptyHistoryView(showRestore: { showingBackupImporter = true })
                        .frame(maxHeight: .infinity)
                }
            } else {
                List {
                    RawScreenTitle(index: "02", title: "Record", detail: "12 WEEKS")
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())

                    HistorySectionControl(selection: $selectedSection)
                        .historyRow(top: 8, bottom: 8)

                    Button { showingExerciseIndex = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                            Text("Find exercise progress")
                            Spacer()
                        }
                        .font(.system(.subheadline, design: .serif, weight: .semibold))
                        .padding(.horizontal, 15)
                        .frame(minHeight: 50)
                        .background(InkPalette.raisedPaper)
                        .overlay { Rectangle().stroke(InkPalette.bronze.opacity(0.62), lineWidth: 1) }
                    }
                    .buttonStyle(PressableButtonStyle())
                    .historyRow(bottom: 10)

                    if selectedSection == .overview {
                        HistoryWeeklySummary(workouts: workouts)
                            .historyRow(top: 10, bottom: 14)
                        HistoryConsistencyView(workouts: workouts)
                            .historyRow(bottom: 14)
                        CoachingReportShareRow(workouts: workouts)
                            .historyRow(bottom: 14)
                        BackupManagementView(
                            workouts: workouts,
                            restore: { showingBackupImporter = true }
                        )
                        .historyRow(bottom: 18)
                    } else {
                        ForEach(workouts) { workout in
                            Button { openWorkout(workout) } label: {
                                HistoryCard(workout: workout)
                            }
                            .buttonStyle(PressableButtonStyle())
                            .historyRow(top: 7, bottom: 7)
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
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .contentMargins(.vertical, 15, for: .scrollContent)
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
    var title: String { rawValue.capitalized }
}

private struct HistorySectionControl: View {
    @Binding var selection: HistorySection

    var body: some View {
        HStack(spacing: 0) {
            ForEach(HistorySection.allCases) { section in
                Button { selection = section } label: {
                    Text(section.title.uppercased())
                        .font(.system(.caption, design: .serif, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(selection == section
                            ? InkPalette.raisedPaper
                            : InkPalette.softInk)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(selection == section
                            ? InkPalette.cinnabar
                            : InkPalette.raisedPaper)
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityAddTraits(selection == section ? .isSelected : [])
            }
        }
        .overlay { Rectangle().stroke(InkPalette.bronze.opacity(0.72), lineWidth: 1) }
    }
}

