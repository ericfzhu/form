import XCTest
import SwiftData
@testable import FormCore

final class NumberEntryTests: XCTestCase {
    private let english = Locale(identifier: "en_AU")

    func testStrictParsingRejectsPartialPastesAndUnsafeNumbers() {
        for text in ["", "-", ".", "12kg", "12 3", "1,234", "1.2.3", "NaN", "inf", "1e9", "1000001", "-2"] {
            XCTAssertNil(NumberEntryRule.load.parse(text, locale: english), text)
        }
        XCTAssertEqual(NumberEntryRule.load.parse(" 12.5 ", locale: english), 12.5)
        XCTAssertEqual(NumberEntryRule.load.parse("0", locale: english), 0)
        XCTAssertNil(NumberEntryRule.count.parse("4.5", locale: english))
        XCTAssertEqual(NumberEntryRule.count.parse("4", locale: english), 4)
    }

    func testDecimalSeparatorsAndUnicodeDigits() {
        let french = Locale(identifier: "fr_FR")
        XCTAssertEqual(NumberEntryRule.load.parse("12,5", locale: french), 12.5)
        XCTAssertEqual(NumberEntryRule.load.parse("12.5", locale: french), 12.5)
        XCTAssertEqual(NumberEntryRule.load.parse("١٢.٥", locale: english), 12.5)
        XCTAssertNil(NumberEntryRule.load.parse("12,5.4", locale: french))
        XCTAssertNil(NumberEntryRule.load.parse("1 234,5", locale: french))
    }

    func testRequiredDurationAndOptionalMeasurements() {
        XCTAssertNil(NumberEntryRule.duration.parse("0", locale: english))
        XCTAssertNil(NumberEntryRule.duration.parse("", locale: english))
        XCTAssertEqual(NumberEntryRule.duration.parse("0.5", locale: english), 0.5)
        XCTAssertEqual(NumberEntryRule.optionalMeasurement.parse("", locale: english), 0)
        XCTAssertNil(NumberEntryRule.optionalMeasurement.parse("-2", locale: english))
        XCTAssertNotNil(NumberEntryRule.duration.problem(.infinity))
    }

    @MainActor func testInvalidDraftSurvivesFocusChangesAndBlocksSaveUntilCorrected() {
        let form = NumberEntryForm(locale: english)
        let specs = [NumberFieldSpec(id: "load", label: "Load", value: 20, rule: .load), NumberFieldSpec(id: "reps", label: "Repetitions", value: 8, rule: .count)]
        form.configure(specs, order: ["load", "reps"])
        form.focusedID = "load"
        XCTAssertNil(form.edit("", id: "load"))
        XCTAssertNil(form.error(for: "load"))
        form.move(1)
        XCTAssertEqual(form.focusedID, "reps")
        XCTAssertEqual(form.error(for: "load"), "Enter a number.")
        form.configure(specs, order: ["load", "reps"])
        XCTAssertEqual(form.text(for: "load", fallback: 20), "")
        XCTAssertFalse(form.validate())
        XCTAssertEqual(form.focusedID, "load")
        XCTAssertEqual(form.edit("22.5", id: "load"), 22.5)
        XCTAssertTrue(form.validate())
        XCTAssertFalse(form.hasInvalidEdits)
    }

    @MainActor func testFocusedSaveUsesCurrentTextAndFormattingDoesNotRoundUntouchedValues() {
        let form = NumberEntryForm(locale: english)
        let original = 1.6333333333
        form.configure([NumberFieldSpec(id: "time", label: "Minutes", value: original, rule: .duration)], order: ["time"])
        form.focusedID = "time"
        // SwiftUI can echo the formatted text when a field gains/loses focus.
        XCTAssertNil(form.edit("1.63", id: "time"))
        form.done()
        XCTAssertEqual(form.drafts["time"]?.spec.value, original)
        XCTAssertFalse(form.drafts["time"]!.edited)
        XCTAssertTrue(form.validate())
        form.focusedID = "time"
        XCTAssertEqual(form.edit("2.75", id: "time"), 2.75)
        XCTAssertTrue(form.validate())
        // A model update from the same keystroke must preserve the raw decimal.
        form.configure([NumberFieldSpec(id: "time", label: "Minutes", value: 2.75, rule: .duration)], order: ["time"])
        XCTAssertEqual(form.text(for: "time", fallback: 0), "2.75")
    }

    @MainActor func testRemovedAndHiddenFieldsCannotBlockSavingOrRemainInFocusOrder() {
        let form = NumberEntryForm(locale: english)
        form.configure([NumberFieldSpec(id: "incline", label: "Incline", value: 0, rule: .optionalMeasurement)], order: ["incline"])
        _ = form.edit("bad", id: "incline")
        XCTAssertFalse(form.validate())
        form.configure([], order: ["title"])
        XCTAssertTrue(form.validate())
        XCTAssertFalse(form.hasInvalidEdits)
        XCTAssertNil(form.focusedID)
    }

    @MainActor func testExternalChangesUpdateFieldsButDoNotDestroyUnrelatedInvalidDrafts() {
        let form = NumberEntryForm(locale: english)
        form.configure([NumberFieldSpec(id: "load", label: "Load", value: 10, rule: .load)], order: ["load"])
        _ = form.edit("10.", id: "load")
        form.configure([NumberFieldSpec(id: "load", label: "Load", value: 10, rule: .load)], order: ["load"])
        XCTAssertEqual(form.text(for: "load", fallback: 0), "10.")
        form.configure([NumberFieldSpec(id: "load", label: "Load", value: 12.5, rule: .load)], order: ["load"])
        XCTAssertEqual(form.text(for: "load", fallback: 0), "12.5")
    }

    @MainActor func testRepositoryRejectsInvalidEditsBeforeChangingHistoryAndAcceptsShortDuration() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: WorkoutRecord.self, ExerciseRecord.self, SetRecord.self, CardioRecord.self, configurations: configuration)
        let context = ModelContext(container)
        let workout = WorkoutRecord(date: Date(), routineID: "test", routineName: "Test", duration: 90)
        context.insert(workout)
        try context.save()
        XCTAssertThrowsError(try WorkoutRepository.update(workout, title: "Changed", date: workout.date, durationMinutes: -1, exercises: [], cardioEntries: [], in: context))
        XCTAssertNil(workout.sessionTitle)
        XCTAssertEqual(workout.duration, 90)
        try WorkoutRepository.update(workout, title: "Short", date: workout.date, durationMinutes: 0.5, exercises: [], cardioEntries: [], in: context)
        XCTAssertEqual(workout.duration, 30)
    }
}
