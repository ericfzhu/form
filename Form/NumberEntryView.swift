import SwiftUI

struct NumberEntryField: View {
    @Environment(NumberEntryForm.self) private var form
    let id: String
    let label: String
    @Binding var value: Double
    var whole = false
    var alignment: TextAlignment = .leading
    var caption: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let caption {
                Text(caption)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(InkPalette.softInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            TextField("0", text: Binding(
                get: { form.text(for: id, fallback: value) },
                set: { text in
                    if let parsed = form.edit(text, id: id) { value = parsed }
                }
            ))
            .keyboardType(whole ? .numberPad : .decimalPad)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .multilineTextAlignment(alignment)
            .inkInput()
            .entryFocus(id)
            .accessibilityLabel(label)
            .accessibilityHint(form.error(for: id) ?? "")
            if let error = form.error(for: id) {
                Text(error).font(.caption).foregroundStyle(InkPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("\(label): \(error)")
            }
        }
        .frame(maxWidth: .infinity)
        .id(id)
    }
}

private struct EntryFocus: ViewModifier {
    @Environment(NumberEntryForm.self) private var form
    @FocusState private var focused: Bool
    let id: String
    func body(content: Content) -> some View {
        content.focused($focused)
            .onChange(of: focused) { _, value in
                if value { form.focusedID = id }
                else {
                    form.reveal(id)
                    if form.focusedID == id { form.focusedID = nil }
                }
            }
            .onChange(of: form.focusedID) { _, value in focused = value == id }
            .onAppear { focused = form.focusedID == id }
            .submitLabel(.next)
            .onSubmit {
                if form.canMove(1) { form.move(1) }
                else { form.done(); dismissKeyboard() }
            }
    }
}

extension View {
    func entryFocus(_ id: String) -> some View { modifier(EntryFocus(id: id)) }
}

struct EntryKeyboardControls: View {
    @Environment(NumberEntryForm.self) private var form
    var adjust: ((Double) -> Void)? = nil

    var body: some View {
        HStack(spacing: 4) {
            CounterweightIconButton(symbol: "chevron.up", label: "Previous field") { form.move(-1) }
                .disabled(!form.canMove(-1))
            CounterweightIconButton(symbol: "chevron.down", label: "Next field") { form.move(1) }
                .disabled(!form.canMove(1))
            Spacer(minLength: 4)
            if let adjust {
                CounterweightIconButton(symbol: "minus", label: "Decrease value") { adjust(-1) }
                CounterweightIconButton(symbol: "plus", label: "Increase value") { adjust(1) }
            }
            CounterweightIconButton(symbol: "checkmark", label: "Done editing") { form.done(); dismissKeyboard() }
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(InkPalette.paper)
    }
}
