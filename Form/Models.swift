import Foundation
import SwiftData

@Model
final class WorkoutRecord {
    var date: Date
    var routineName: String
    var duration: TimeInterval

    @Relationship(deleteRule: .cascade, inverse: \ExerciseRecord.workout)
    var exercises: [ExerciseRecord]

    init(date: Date, routineName: String, duration: TimeInterval, exercises: [ExerciseRecord] = []) {
        self.date = date
        self.routineName = routineName
        self.duration = duration
        self.exercises = exercises
    }
}

@Model
final class ExerciseRecord {
    var name: String
    var assetName: String
    var order: Int
    var workout: WorkoutRecord?

    @Relationship(deleteRule: .cascade, inverse: \SetRecord.exercise)
    var sets: [SetRecord]

    init(name: String, assetName: String, order: Int, sets: [SetRecord] = []) {
        self.name = name
        self.assetName = assetName
        self.order = order
        self.sets = sets
    }
}

@Model
final class SetRecord {
    var order: Int
    var weight: Double
    var repetitions: Int
    var exercise: ExerciseRecord?

    init(order: Int, weight: Double, repetitions: Int) {
        self.order = order
        self.weight = weight
        self.repetitions = repetitions
    }
}
