import Testing
@testable import FormCore

private let weighted = ProgressionPrescription(
    measurement: .weighted,
    prescribedSets: 3,
    minimumRepetitions: 6,
    maximumRepetitions: 10,
    loadIncrement: 2.5
)

@Test func increasesAfterCompletingTheTopOfTheRange() {
    let result = ProgressionRules.decision(
        prescription: weighted,
        performances: [
            ProgressionInputPerformance(sets: [
                .init(weight: 60, repetitions: 10),
                .init(weight: 60, repetitions: 10),
                .init(weight: 60, repetitions: 10)
            ])
        ]
    )
    #expect(result == .increaseLoad(62.5))
}

@Test func weightedProgressionAllowsBackoffSetsAtTheTopOfTheRange() {
    let result = ProgressionRules.decision(
        prescription: weighted,
        performances: [
            ProgressionInputPerformance(sets: [
                .init(weight: 62.5, repetitions: 10),
                .init(weight: 60, repetitions: 10),
                .init(weight: 60, repetitions: 10)
            ])
        ]
    )
    #expect(result == .increaseLoad(65))
}

@Test func reducesAfterTwoConsecutiveShortfalls() {
    let short = ProgressionInputPerformance(sets: [
        .init(weight: 60, repetitions: 5),
        .init(weight: 60, repetitions: 5),
        .init(weight: 60, repetitions: 5)
    ])
    let result = ProgressionRules.decision(
        prescription: weighted,
        performances: [short, short]
    )
    #expect(result == .reduceLoad(57.5))
}

@Test func weightedTimedExerciseRequestsALoadBeforeProgressing() {
    let prescription = ProgressionPrescription(
        measurement: .weightedTimed,
        prescribedSets: 3,
        minimumRepetitions: 30,
        maximumRepetitions: 45,
        loadIncrement: 2.5
    )
    let result = ProgressionRules.decision(
        prescription: prescription,
        performances: [
            ProgressionInputPerformance(sets: [
                .init(weight: 0, repetitions: 45)
            ])
        ]
    )
    #expect(result == .recordLoad)
}

@Test func timedExerciseUsesATimeDecision() {
    let prescription = ProgressionPrescription(
        measurement: .timed,
        prescribedSets: 2,
        minimumRepetitions: 30,
        maximumRepetitions: 45,
        loadIncrement: 2.5
    )
    let result = ProgressionRules.decision(
        prescription: prescription,
        performances: [
            ProgressionInputPerformance(sets: [
                .init(weight: 0, repetitions: 35)
            ])
        ]
    )
    #expect(result == .addTime)
}
