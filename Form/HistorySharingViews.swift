import SwiftUI
import UniformTypeIdentifiers

/// The menu, index, detail and restore result keep one sheet presentation alive.
struct HistoryOptionsDrawer: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var path = NavigationPath()
    @State private var detent: PresentationDetent = .medium
    @State private var showingImporter = false
    @State private var restoreMessage: String?
    private enum Destination: Hashable { case exercises }
    let workouts: [WorkoutRecord]
    let restore: (Result<[URL], Error>) -> String?

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let restoreMessage {
                        Text(restoreMessage).font(.subheadline).foregroundStyle(InkPalette.softInk)
                            .fixedSize(horizontal: false, vertical: true)
                        InkPrimaryButton(title: "Done") { dismiss() }
                    } else {
                        options
                    }
                }
                .padding(.horizontal, CounterweightLayout.pageInset)
                .padding(.top, 12).padding(.bottom, 32)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                CounterweightSheetHeader(
                    title: restoreMessage == nil ? "History" : "Restore backup",
                    back: restoreMessage == nil ? nil : returnToOptions,
                    close: { dismiss() }
                )
            }
            .background(InkPalette.paper)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Destination.self) { _ in
                ExerciseIndexView(close: { dismiss() })
            }
            .navigationDestination(for: ExerciseTemplate.self) { exercise in
                ExerciseProgressView(exercise: exercise, closeDrawer: { dismiss() })
            }
        }
        .foregroundStyle(InkPalette.ink)
        .tint(InkPalette.ink)
        .presentationBackground(InkPalette.paper)
        .presentationCornerRadius(28)
        .presentationDragIndicator(.visible)
        .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.medium, .large], selection: $detent)
        .onChange(of: typeSize, initial: true) { _, size in
            if size.isAccessibilitySize { detent = .large }
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            // Files stays system-owned; its result updates the drawer underneath it.
            let message = restore(result)
            withAnimation(reduceMotion ? nil : CounterweightMotion.quiet) { restoreMessage = message }
        }
    }

    private var options: some View {
        Group {
            CounterweightActionRow(title: "Exercise progress", symbol: "chart.xyaxis.line") {
                withAnimation(reduceMotion ? nil : CounterweightMotion.quiet) {
                    detent = .large
                    path.append(Destination.exercises)
                }
            }
            InkDivider()
            ShareLink(item: WorkoutBackup(workouts: workouts), preview: SharePreview("Form workout backup")) {
                HStack(spacing: 14) {
                    Image(systemName: "square.and.arrow.up").font(.system(size: 16, weight: .medium))
                        .frame(width: 40, height: 40).background(InkPalette.mist, in: Circle())
                    Text("Export a backup").font(.subheadline.weight(.medium))
                    Spacer()
                }.foregroundStyle(InkPalette.ink).padding(.vertical, 5).contentShape(Rectangle())
            }.buttonStyle(PressableButtonStyle())
            CounterweightActionRow(title: "Restore a backup", symbol: "arrow.down.document") {
                showingImporter = true
            }
        }
    }

    private func returnToOptions() {
        withAnimation(reduceMotion ? nil : CounterweightMotion.quiet) { restoreMessage = nil }
    }
}

struct ExerciseIndexView: View {
    @Environment(\.dismiss) private var dismiss
    let close: () -> Void
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool

    private var exercises: [ExerciseTemplate] {
        let all = WorkoutCatalog.allExercises.uniquedByName()
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        ZStack {
            PaperBackground()
            VStack(spacing: 0) {
                CounterweightSheetHeader(title: "Exercise progress", back: { dismiss() }, close: close)

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(InkPalette.softInk)
                    TextField("Search exercises", text: $searchText)
                        .accessibilityLabel("Search exercises")
                        .focused($searchFocused)
                        .submitLabel(.search)
                        .onSubmit { searchFocused = false }
                        .font(.system(.body, design: .default))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if !searchText.isEmpty {
                        CounterweightIconButton(symbol: "xmark", label: "Clear search") { searchText = ""; searchFocused = true }
                    }
                }
                .frame(minHeight: 52)
                .padding(.horizontal, 14)
                .background(InkPalette.mist, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24).padding(.bottom, 12)

                if exercises.isEmpty {
                    Text("No exercises match “\(searchText)”.")
                        .font(.subheadline).foregroundStyle(InkPalette.softInk)
                        .padding(20)
                }
                List(exercises) { exercise in
                    NavigationLink(value: exercise) {
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(exercise.name)
                                    .font(.system(.body, design: .default))
                                Text(exercise.targetText)
                                    .font(.system(.caption2, design: .default))
                                    .foregroundStyle(InkPalette.softInk.opacity(0.8))
                            }
                            Spacer()
                            DemonstrationImage(assetName: exercise.assetName, outlined: false)
                                .frame(width: 72, height: 64)
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: CounterweightLayout.pageInset, bottom: 0, trailing: CounterweightLayout.pageInset))
                }
                .scrollDismissesKeyboard(.interactively)
                .listStyle(.plain)
                .contentMargins(.top, 0, for: .scrollContent)
                .scrollContentBackground(.hidden)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .background { InteractivePopGestureBridge(isEnabled: true) }
    }
}

struct CoachingReportShareRow: View {
    let workouts: [WorkoutRecord]

    var body: some View {
        ShareLink(
            item: CoachingReportBuilder.build(from: workouts),
            preview: SharePreview("Form coaching report")
        ) {
            recordAction(
                title: "Coaching report",
                detail: "12 weeks · \(includedSessionCount) session\(includedSessionCount == 1 ? "" : "s")",
                symbol: "square.and.arrow.up"
            )
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var includedSessionCount: Int {
        workouts.filter { ProgressPeriod.twelveWeeks.includes($0.date) }.count
    }
}

struct BackupManagementView: View {
    let workouts: [WorkoutRecord]
    let restore: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ShareLink(
                item: WorkoutBackup(workouts: workouts),
                preview: SharePreview("Form workout backup")
            ) {
                recordAction(
                    title: "Workout backup",
                    detail: "\(workouts.count) session\(workouts.count == 1 ? "" : "s")",
                    symbol: "square.and.arrow.up"
                )
            }
            .buttonStyle(PressableButtonStyle())

            Button(action: restore) {
                recordAction(title: "Restore backup", detail: "Existing sessions are never duplicated", symbol: "arrow.down.document")
            }
            .buttonStyle(PressableButtonStyle())
        }
    }
}

private func recordAction(
    title: String,
    detail: String,
    symbol: String
) -> some View {
    HStack(spacing: 14) {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.medium))
            Text(detail)
                .font(.caption)
                .foregroundStyle(InkPalette.softInk)
                .monospacedDigit()
        }
        Spacer(minLength: 12)
        Image(systemName: symbol).font(.system(size: 16, weight: .medium))
            .frame(width: 44, height: 44).background(InkPalette.mist, in: Circle())
            .accessibilityHidden(true)
    }
    .frame(minHeight: 72)
    .contentShape(Rectangle())
}
