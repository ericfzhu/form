import SwiftUI
import SwiftData

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack {
                RoutineListView()
            }
            .tabItem {
                Label("Train", systemImage: "figure.strengthtraining.traditional")
            }

            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label("History", systemImage: "clock.arrow.circlepath")
            }
        }
        .tint(.black)
    }
}

private struct RoutineListView: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("FORM")
                        .font(.caption.weight(.bold))
                        .tracking(2.4)
                    Text("Train with intent.")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("Continue the A → B → C rotation, regardless of how many times you train this week.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 10)

                ForEach(WorkoutCatalog.routines) { routine in
                    NavigationLink(value: routine) {
                        RoutineCard(routine: routine)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationDestination(for: RoutineTemplate.self) { routine in
            RoutineDetailView(routine: routine)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct RoutineCard: View {
    let routine: RoutineTemplate

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.black)
                Text(routine.id)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }
            .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 5) {
                Text(routine.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(routine.focus)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct RoutineDetailView: View {
    let routine: RoutineTemplate
    @State private var showingWorkout = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(routine.exercises.enumerated()), id: \.element.id) { index, exercise in
                    ExercisePreviewRow(index: index + 1, exercise: exercise)
                }
            }
            .padding(20)
            .padding(.bottom, 88)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(routine.name)
        .navigationBarTitleDisplayMode(.large)
        .safeAreaInset(edge: .bottom) {
            Button {
                showingWorkout = true
            } label: {
                Text("Start workout")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(.black, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
        .fullScreenCover(isPresented: $showingWorkout) {
            NavigationStack {
                ActiveWorkoutView(routine: routine)
            }
        }
    }
}

private struct ExercisePreviewRow: View {
    let index: Int
    let exercise: ExerciseTemplate

    var body: some View {
        HStack(spacing: 14) {
            DemonstrationImage(assetName: exercise.assetName)
                .frame(width: 94, height: 94)

            VStack(alignment: .leading, spacing: 7) {
                Text(String(format: "%02d", index))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(exercise.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(exercise.targetText)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.045), radius: 9, y: 3)
    }
}

struct DemonstrationImage: View {
    let assetName: String

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFill()
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.black.opacity(0.10), lineWidth: 1)
            }
            .accessibilityLabel("Abstract demonstration")
    }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
