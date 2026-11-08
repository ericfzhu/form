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
    @State private var pendingDeletion: WorkoutRecord?
    let openWorkout: (WorkoutRecord) -> Void

    private struct MonthPage: Identifiable {
        let id: Date
        let workouts: [WorkoutRecord]
    }

    private var months: [MonthPage] {
        Dictionary(grouping: workouts) {
            Calendar.current.dateInterval(of: .month, for: $0.date)?.start ?? $0.date
        }
        .map { MonthPage(id: $0.key, workouts: $0.value.sorted { $0.date > $1.date }) }
        .sorted { $0.id > $1.id }
    }

    private var pageHeading: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("History").font(.title2.weight(.bold)).accessibilityAddTraits(.isHeader)
            if !workouts.isEmpty {
                Text("\(workouts.count) saved session\(workouts.count == 1 ? "" : "s")")
                    .font(.caption).foregroundStyle(InkPalette.softInk)
                HistorySectionControl(selection: $selectedSection)
            }
        }
    }

    var body: some View {
        ZStack {
            PaperBackground()
            if workouts.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        pageHeading
                        EmptyHistoryView(showRestore: { showingBackupImporter = true })
                    }
                    .padding(20)
                }
            } else {
                List {
                    pageHeading.historyRow(top: 12, bottom: 12)
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
                        ForEach(months) { month in
                            Text(month.id.formatted(.dateTime.month(.wide).year()).lowercased())
                                .font(.subheadline.weight(.medium)).foregroundStyle(InkPalette.softInk)
                                .accessibilityAddTraits(.isHeader)
                                .historyRow(top: 20, bottom: 0)
                            ForEach(month.workouts) { workout in
                                Button { openWorkout(workout) } label: {
                                    HistoryCard(workout: workout)
                                }
                                .buttonStyle(PressableButtonStyle())
                                .historyRow()
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) { pendingDeletion = workout } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .tint(InkPalette.cinnabar)
                                }
                                .contextMenu {
                                    Button("Delete session", role: .destructive) {
                                        pendingDeletion = workout
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .contentMargins(.bottom, 18, for: .scrollContent)
            }
        }
        .safeAreaInset(edge: .top) {
            HStack {
                FormWordmark()
                Spacer()
                Menu {
                    Button("Sessions") { selectedSection = .sessions }
                    Button("Overview") { selectedSection = .overview }
                    Button("Exercise progress") { showingExerciseIndex = true }
                    Divider()
                    ShareLink(item: WorkoutBackup(workouts: workouts), preview: SharePreview("Form workout backup")) {
                        Label("Export a backup", systemImage: "square.and.arrow.up")
                    }
                    Button("Restore a backup") { showingBackupImporter = true }
                } label: { Image(systemName: "ellipsis").font(.system(size: 22)).frame(width: 44, height: 44) }
                    .accessibilityLabel("History options")
                Button { showingSettings = true } label: {
                    Image(systemName: "slider.horizontal.3").font(.system(size: 22)).frame(width: 44, height: 44)
                }.accessibilityLabel("Settings")
            }.padding(.horizontal, 28).background(InkPalette.paper.ignoresSafeArea(edges: .top))
        }
        .confirmationDialog("Delete this session?", isPresented: Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        ), presenting: pendingDeletion) { workout in
            Button("Delete session", role: .destructive) {
                delete(workout)
                pendingDeletion = nil
            }
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
        } message: { workout in
            Text("Delete \(workout.displayName)? This also requests removal of its Apple Health workout and can’t be undone.")
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
        do {
            try withAnimation(.easeOut(duration: 0.2)) {
                try WorkoutRepository.delete(workout, in: modelContext)
            }
            Task {
                await HealthSyncCoordinator.shared.enqueueDelete(
                    recordIdentifier: identifier,
                    workoutUUID: healthUUID
                )
            }
        } catch {
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
        } catch let error as CocoaError where error.code == .userCancelled {
            return
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selectionMark
    @Binding var selection: HistorySection
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 24))
        return layout {
            ForEach(HistorySection.allCases) { section in
                Button { withAnimation(reduceMotion ? nil : CounterweightMotion.disclosure) { selection = section } } label: {
                    Text(section.title)
                        .font(.subheadline)
                        .foregroundStyle(selection == section
                            ? InkPalette.ink
                            : InkPalette.softInk.opacity(0.68))
                        .frame(minWidth: 84, minHeight: 46)
                        .overlay(alignment: .bottom) {
                            if selection == section {
                                Circle().fill(InkPalette.ink)
                                    .frame(width: 4, height: 4)
                                    .matchedGeometryEffect(id: "section", in: selectionMark)
                            }
                        }
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityAddTraits(selection == section ? .isSelected : [])
            }
            if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
        }
    }
}
