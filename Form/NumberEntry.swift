import Foundation
import Observation

/// Strict, locale-aware input rules. Grouping separators and numeric prefixes
/// are deliberately not accepted: pasted text must describe one whole value.
struct NumberEntryRule: Equatable {
    var whole = false
    var positive = false
    var blankIsZero = false
    static let load = NumberEntryRule()
    static let count = NumberEntryRule(whole: true)
    static let duration = NumberEntryRule(positive: true)
    static let optionalMeasurement = NumberEntryRule(blankIsZero: true)
    static let maximum = 1_000_000.0

    func parse(_ text: String, locale: Locale) -> Double? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return blankIsZero ? 0 : nil }
        let separator = locale.decimalSeparator ?? "."
        var normalized = ""
        var decimalSeen = false
        for (index, character) in text.enumerated() {
            if let digit = character.wholeNumberValue, (0...9).contains(digit) {
                normalized.append(String(digit))
            } else if (String(character) == separator || character == "."), !decimalSeen {
                normalized.append(".")
                decimalSeen = true
            } else if character == "-", index == 0 {
                normalized.append("-")
            } else { return nil }
        }
        guard let value = Double(normalized), problem(value) == nil else { return nil }
        return value
    }

    func problem(_ value: Double) -> String? {
        guard value.isFinite else { return "Enter a valid number." }
        if positive && value <= 0 { return "Enter a duration greater than zero." }
        if value < 0 { return "Enter zero or a positive number." }
        if value > Self.maximum { return "Enter a number no greater than 1,000,000." }
        if whole && value.rounded(.towardZero) != value { return "Enter a whole number." }
        return nil
    }

    func message(for text: String, locale: Locale) -> String? {
        if parse(text, locale: locale) != nil { return nil }
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Enter a number." }
        if text.hasPrefix("-") { return positive ? "Enter a duration greater than zero." : "Enter zero or a positive number." }
        if positive, Double(text.replacingOccurrences(of: locale.decimalSeparator ?? ".", with: ".")) == 0 {
            return "Enter a duration greater than zero."
        }
        if let value = Double(text.replacingOccurrences(of: locale.decimalSeparator ?? ".", with: ".")), value > Self.maximum {
            return "Enter a number no greater than 1,000,000."
        }
        return whole ? "Enter a whole number." : "Enter a valid number."
    }
}

struct NumberFieldSpec: Equatable {
    let id: String
    let label: String
    let value: Double
    let rule: NumberEntryRule
}

enum EntryID {
    static let title = "session-title"
    static let duration = "session-duration"
    static func load(_ id: UUID) -> String { "set-\(id)-load" }
    static func count(_ id: UUID) -> String { "set-\(id)-count" }
    static func cardio(_ id: UUID, _ field: String) -> String { "cardio-\(id)-\(field)" }
}

@MainActor @Observable
final class NumberEntryForm {
    struct Draft {
        var spec: NumberFieldSpec
        var text: String
        var edited = false
        var revealed = false
    }
    private(set) var drafts: [String: Draft] = [:]
    private(set) var order: [String] = []
    var focusedID: String?
    private(set) var focusRequest = UUID()
    let locale: Locale

    init(locale: Locale = .current) { self.locale = locale }

    func configure(_ specs: [NumberFieldSpec], order: [String]) {
        self.order = order
        let ids = Set(specs.map(\.id))
        drafts = drafts.filter { ids.contains($0.key) }
        for spec in specs {
            if var draft = drafts[spec.id] {
                if draft.spec.value != spec.value,
                   draft.spec.rule.parse(draft.text, locale: locale) != spec.value {
                    draft.text = format(spec.value)
                    draft.edited = false
                }
                draft.spec = spec
                drafts[spec.id] = draft
            } else {
                drafts[spec.id] = Draft(spec: spec, text: format(spec.value))
            }
        }
        if let focusedID, !order.contains(focusedID) { self.focusedID = nil }
    }

    func text(for id: String, fallback: Double) -> String { drafts[id]?.text ?? format(fallback) }

    @discardableResult
    func edit(_ text: String, id: String) -> Double? {
        guard var draft = drafts[id] else { return nil }
        // TextField can echo its displayed string when focus changes. Do not
        // write that rounded presentation back over an untouched measurement.
        guard text != draft.text else { return nil }
        draft.text = text
        draft.edited = true
        drafts[id] = draft
        return draft.spec.rule.parse(text, locale: locale)
    }

    func reveal(_ id: String) { drafts[id]?.revealed = true }

    func error(for id: String) -> String? {
        guard let draft = drafts[id], draft.revealed else { return nil }
        return problem(draft)
    }

    private func problem(_ draft: Draft) -> String? {
        // Merely focusing/formatting a value must not round the saved measurement.
        draft.edited ? draft.spec.rule.message(for: draft.text, locale: locale) : draft.spec.rule.problem(draft.spec.value)
    }

    var hasInvalidEdits: Bool { drafts.values.contains { $0.edited && problem($0) != nil } }

    var editedTexts: [String: String] {
        drafts.filter { $0.value.edited }.mapValues(\.text)
    }

    var invalidIDs: Set<String> {
        Set(drafts.filter { problem($0.value) != nil }.keys)
    }

    func restoreEditedTexts(_ texts: [String: String]) {
        for (id, text) in texts where drafts[id] != nil {
            drafts[id]?.text = text
            drafts[id]?.edited = true
        }
    }

    /// Explicit copy actions replace raw drafts even when the numeric value is unchanged.
    func replaceValue(_ value: Double, id: String) {
        guard var draft = drafts[id] else { return }
        draft.text = format(value)
        draft.edited = false
        draft.revealed = false
        draft.spec = NumberFieldSpec(id: id, label: draft.spec.label, value: value, rule: draft.spec.rule)
        drafts[id] = draft
    }

    @discardableResult
    func validate(ids: [String]? = nil) -> Bool {
        let ids = ids ?? order
        for id in ids { reveal(id) }
        if let first = ids.first(where: { id in drafts[id].map { problem($0) != nil } ?? false }) {
            requestFocus(first)
            return false
        }
        return true
    }

    func canMove(_ offset: Int) -> Bool {
        guard let focusedID, let index = order.firstIndex(of: focusedID) else { return false }
        return order.indices.contains(index + offset)
    }

    func move(_ offset: Int) {
        guard let focusedID, let index = order.firstIndex(of: focusedID), canMove(offset) else { return }
        reveal(focusedID)
        requestFocus(order[index + offset])
    }

    func requestFocus(_ id: String) {
        focusedID = id
        focusRequest = UUID()
    }

    func done() {
        if let focusedID { reveal(focusedID) }
        focusedID = nil
    }

    func format(_ value: Double) -> String {
        value.formatted(.number.grouping(.never).precision(.fractionLength(0...2)).locale(locale))
    }
}

extension CardioDraft {
    var numberFields: [NumberFieldSpec] {
        var fields = [
            NumberFieldSpec(id: EntryID.cardio(id, "minutes"), label: "\(kind.title), minutes", value: durationMinutes, rule: .duration),
            NumberFieldSpec(id: EntryID.cardio(id, "distance"), label: "\(kind.title), distance in kilometres", value: distanceKilometers, rule: .optionalMeasurement),
            NumberFieldSpec(id: EntryID.cardio(id, "speed"), label: "\(kind.title), speed in kilometres per hour", value: averageSpeed, rule: .optionalMeasurement)
        ]
        if kind.supportsIncline {
            fields.append(NumberFieldSpec(id: EntryID.cardio(id, "incline"), label: "\(kind.title), incline percent", value: incline, rule: .optionalMeasurement))
        }
        return fields
    }
}
