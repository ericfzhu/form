import SwiftData
import SwiftUI
import UIKit

enum InkPalette {
    static let ink = Color(red: 5 / 255, green: 18 / 255, blue: 48 / 255)
    static let softInk = Color(red: 65 / 255, green: 80 / 255, blue: 101 / 255)
    static let paper = Color.white
    static let salvia = Color(red: 151 / 255, green: 172 / 255, blue: 200 / 255)
    static let washedInk = Color(red: 182 / 255, green: 191 / 255, blue: 193 / 255)
    static let plum = ink
    static let verdigris = ink
    static let steel = softInk
    static let mist = salvia.opacity(0.16)
    static let mineral = ink
    static let cinnabar = ink
    static let bronze = washedInk
    static let acid = steel
}

enum AtelierType {
    static func script(_ size: CGFloat) -> Font {
        .custom("HelveticaNeue-Medium", size: min(size, 28), relativeTo: size >= 24 ? .title2 : .body)
    }
}

/// Short, interruptible feedback. Persistence never waits for decorative motion.
enum CounterweightMotion {
    static let press = Animation.spring(response: 0.22, dampingFraction: 0.78)
    static let disclosure = Animation.spring(response: 0.34, dampingFraction: 0.9)
    static let settle = Animation.spring(response: 0.46, dampingFraction: 0.8)
    static let quiet = Animation.easeOut(duration: 0.18)
    static let expand = Animation.spring(response: 0.38, dampingFraction: 1)
    static func transition(reduced: Bool) -> AnyTransition {
        reduced ? .opacity : .offset(y: 8).combined(with: .opacity)
    }
}

/// The content keeps its natural size while its visible height changes.
/// No opacity blend, duplicated editor, or changing text layout during expansion.
struct CounterweightRevealLayout: Layout {
    var amount: CGFloat
    var animatableData: CGFloat {
        get { amount }
        set { amount = newValue }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let size = subviews.first?.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil)) ?? .zero
        return CGSize(width: size.width, height: size.height * max(0, min(1, amount)))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, anchor: .topLeading,
                             proposal: ProposedViewSize(width: bounds.width, height: nil))
    }
}

struct CounterweightControl: View {
    @Environment(\.isEnabled) private var isEnabled
    let title: String
    let symbol: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol).font(.system(size: 13, weight: .medium))
                Text(title).font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 14).frame(minHeight: 44)
            .background(InkPalette.mist, in: Capsule())
            .overlay { Capsule().strokeBorder(InkPalette.ink.opacity(0.09), lineWidth: 1) }
            .foregroundStyle(InkPalette.ink).contentShape(Capsule())
        }.buttonStyle(PressableButtonStyle()).opacity(isEnabled ? 1 : 0.4)
    }
}

struct CounterweightIconButton: View {
    @Environment(\.isEnabled) private var isEnabled
    let symbol: String
    let label: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 16, weight: .medium))
                .foregroundStyle(InkPalette.ink).frame(width: 44, height: 44)
                .background(InkPalette.mist, in: Circle())
                .overlay { Circle().strokeBorder(InkPalette.ink.opacity(0.09), lineWidth: 1) }
                .contentShape(Circle())
        }.buttonStyle(PressableButtonStyle()).accessibilityLabel(label).opacity(isEnabled ? 1 : 0.4)
    }
}

struct CounterweightSheet<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    let title: String
    var subtitle: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20, content: content)
                .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 32)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            CounterweightSheetHeader(title: title, subtitle: subtitle) { dismiss() }
        }
        .background(InkPalette.paper)
        .foregroundStyle(InkPalette.ink)
        .presentationBackground(InkPalette.paper)
        .presentationCornerRadius(28)
        .presentationDragIndicator(.visible)
        .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.medium, .large])
    }
}

struct CounterweightSheetHeader: View {
    let title: String
    var subtitle: String? = nil
    let close: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.title3.weight(.semibold))
                    .frame(minHeight: 44, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(InkPalette.softInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            CounterweightIconButton(symbol: "xmark", label: "Close \(title)", action: close)
        }
        .padding(.horizontal, CounterweightLayout.pageInset)
        .padding(.vertical, 6)
        .foregroundStyle(InkPalette.ink)
        .background(InkPalette.paper.ignoresSafeArea(edges: .top))
    }
}

struct CounterweightChoice: View {
    let title: String
    let selected: Bool
    var compact = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).font((compact ? Font.caption : .subheadline).weight(.medium))
                .multilineTextAlignment(.center)
                .padding(.horizontal, compact ? 8 : 14).padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(selected ? InkPalette.paper : InkPalette.ink)
                .background(selected ? InkPalette.ink : InkPalette.mist, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Used for app-owned confirmations. Closing the sheet never confirms an action.
struct CounterweightConfirmationSheet: View {
    let title: String
    let message: String
    let actionTitle: String
    var destructive = false
    var cancelTitle = "Cancel"
    let confirm: () -> Void
    let cancel: () -> Void

    var body: some View {
        CounterweightSheet(title: title) {
            Text(message).font(.subheadline).foregroundStyle(InkPalette.softInk)
                .fixedSize(horizontal: false, vertical: true)
            if destructive {
                CounterweightActionRow(title: actionTitle, symbol: "trash", destructive: true, action: confirm)
                InkPrimaryButton(title: cancelTitle, action: cancel)
            } else {
                InkPrimaryButton(title: actionTitle, action: confirm)
                CounterweightControl(title: cancelTitle, symbol: "arrow.left", action: cancel)
            }
        }
    }
}

extension View {
    func counterweightNotice(_ title: String, message: Binding<String?>) -> some View {
        sheet(item: Binding(get: { message.wrappedValue.map(CounterweightNoticeMessage.init) }, set: {
            if $0 == nil { message.wrappedValue = nil }
        })) { notice in
            CounterweightSheet(title: title) {
                Text(notice.text).font(.subheadline).foregroundStyle(InkPalette.softInk)
                    .fixedSize(horizontal: false, vertical: true)
                InkPrimaryButton(title: "Done") { message.wrappedValue = nil }
            }
        }
    }
}

private struct CounterweightNoticeMessage: Identifiable {
    let text: String
    var id: String { text }
}

struct CounterweightActionRow: View {
    @Environment(\.isEnabled) private var isEnabled
    let title: String
    let symbol: String
    var destructive = false
    var action: () -> Void
    var body: some View {
        Button(role: destructive ? .destructive : nil, action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol).font(.system(size: 16, weight: .medium))
                    .frame(width: 40, height: 40).background(InkPalette.mist, in: Circle())
                Text(title).font(.subheadline.weight(.medium)).multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }.foregroundStyle(InkPalette.ink).padding(.vertical, 5)
                .opacity(isEnabled ? 1 : 0.4).contentShape(Rectangle())
        }.buttonStyle(PressableButtonStyle())
    }
}

struct CounterweightDiscardSheet: View {
    let discard: () -> Void
    let keep: () -> Void
    var body: some View {
        CounterweightSheet(title: "Discard workout?") {
            Text("This removes the unfinished session. Your saved workout history is kept.")
                .font(.subheadline).foregroundStyle(InkPalette.softInk)
            CounterweightActionRow(title: "Discard workout", symbol: "trash", destructive: true, action: discard)
            InkPrimaryButton(title: "Keep workout", action: keep)
        }
    }
}

struct CounterweightFigure: View {
    var resting = false
    var body: some View {
        GeometryReader { geometry in
            Image("counterweight-session").resizable()
                .frame(width: geometry.size.width * 3, height: geometry.size.width)
                .offset(x: -geometry.size.width * (resting ? 2 : 1))
        }
        .aspectRatio(1, contentMode: .fit)
        .clipped()
        .accessibilityHidden(true)
    }
}

struct FormWordmark: View {
    var body: some View {
        Text("form").font(.system(size: 27, weight: .bold)).tracking(-1.5)
            .accessibilityHidden(true)
    }
}

enum CounterweightLayout {
    static let pageInset: CGFloat = 24
    static let headerHeight: CGFloat = 56
}

/// Keep the brand and trailing action anchored when the screen's actions change.
struct CounterweightHeader<Actions: View>: View {
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        HStack(spacing: 8) {
            FormWordmark()
            Spacer(minLength: 8)
            HStack(spacing: 8, content: actions)
        }
        .frame(minHeight: CounterweightLayout.headerHeight)
        .padding(.horizontal, CounterweightLayout.pageInset)
        .background(InkPalette.paper.ignoresSafeArea(edges: .top))
    }
}

struct PaperSurface: View {
    var body: some View { InkPalette.paper }
}

struct PaperBackground: View {
    var body: some View {
        InkPalette.paper.ignoresSafeArea()
    }
}

struct InkDivider: View {
    var body: some View {
        Rectangle()
            .fill(InkPalette.ink.opacity(0.12))
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

struct RawScreenTitle: View {
    let index: String
    let title: String
    var detail: String = ""
    @ScaledMetric(relativeTo: .title2) private var titleSize = 24

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title.lowercased())
                    .font(AtelierType.script(titleSize))
                    .foregroundStyle(InkPalette.ink)
                    .minimumScaleFactor(0.62)
                    .lineLimit(1)
                Spacer()
                if !detail.isEmpty {
                    Text(detail.lowercased())
                        .font(AtelierType.script(14))
                        .foregroundStyle(InkPalette.softInk.opacity(0.62))
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(detail.isEmpty ? title : "\(title), \(detail)")
        .accessibilityAddTraits(.isHeader)
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct FieldSectionTitle: View {
    let title: String
    var detail: String = ""

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title.lowercased())
                .font(AtelierType.script(14))
                .foregroundStyle(InkPalette.ink)
            Spacer()
            if !detail.isEmpty {
                Text(detail.lowercased())
                    .font(AtelierType.script(13))
                    .foregroundStyle(InkPalette.softInk.opacity(0.62))
            }
        }
        .frame(minHeight: 40)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

struct RawSectionHeader: View {
    let index: String
    let title: String
    var trailing: String = ""

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title.lowercased())
                .font(AtelierType.script(15))
            Spacer()
            if !trailing.isEmpty {
                Text(trailing.lowercased())
                    .font(AtelierType.script(13))
                    .foregroundStyle(InkPalette.softInk.opacity(0.68))
            }
        }
        .padding(.horizontal, 2)
        .frame(minHeight: 48)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(trailing.isEmpty ? title : "\(title), \(trailing)")
        .accessibilityAddTraits(.isHeader)
    }
}

struct InkTextHeader: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let title: String
    let leadingTitle: String
    let leadingAction: () -> Void
    var trailingTitle: String?
    var trailingAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(HStackLayout(spacing: 12))
                : AnyLayout(CounterweightNavigationLayout())
            layout {
                CounterweightControl(title: leadingTitle, symbol: leadingTitle == "Back" ? "arrow.left" : "xmark", action: leadingAction)
                    .lineLimit(1).minimumScaleFactor(0.75)
                if typeSize.isAccessibilitySize { Spacer(minLength: 0) }
                else {
                    Text(title).font(.subheadline.weight(.medium)).lineLimit(1)
                        .minimumScaleFactor(0.76).frame(maxWidth: .infinity)
                        .accessibilityAddTraits(.isHeader)
                }
                if let trailingTitle, let trailingAction {
                    CounterweightControl(title: trailingTitle, symbol: "checkmark", action: trailingAction)
                        .lineLimit(1).minimumScaleFactor(0.75)
                } else if !typeSize.isAccessibilitySize {
                    Color.clear.frame(width: 0, height: 44).accessibilityHidden(true)
                }
            }
            .frame(minHeight: CounterweightLayout.headerHeight)
            if typeSize.isAccessibilitySize {
                Text(title).font(.headline).fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8).padding(.bottom, 12).accessibilityAddTraits(.isHeader)
            }
        }
        .padding(.horizontal, CounterweightLayout.pageInset)
        .background { PaperSurface().ignoresSafeArea(edges: .top) }
    }
}

/// Balance the title around the screen center, regardless of the two action widths.
private struct CounterweightNavigationLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 350
        let side = max(subviews[0].sizeThatFits(.unspecified).width, subviews[2].sizeThatFits(.unspecified).width)
        let title = subviews[1].sizeThatFits(ProposedViewSize(width: max(0, width - 2 * (side + 12)), height: nil))
        return CGSize(width: width, height: max(44, title.height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let side = max(subviews[0].sizeThatFits(.unspecified).width, subviews[2].sizeThatFits(.unspecified).width)
        subviews[0].place(at: CGPoint(x: bounds.minX, y: bounds.midY), anchor: .leading, proposal: .unspecified)
        subviews[1].place(at: CGPoint(x: bounds.midX, y: bounds.midY), anchor: .center,
                          proposal: ProposedViewSize(width: max(0, bounds.width - 2 * (side + 12)), height: nil))
        subviews[2].place(at: CGPoint(x: bounds.maxX, y: bounds.midY), anchor: .trailing, proposal: .unspecified)
    }
}

private struct InkCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(Color.clear)
    }
}

@MainActor
func dismissKeyboard() {
    UIApplication.shared.sendAction(
        #selector(UIResponder.resignFirstResponder),
        to: nil,
        from: nil,
        for: nil
    )
}

extension View {
    func inkCard() -> some View { modifier(InkCardModifier()) }

    func keyboardDismissToolbar() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { dismissKeyboard() }
                    .font(AtelierType.script(18))
                    .tint(InkPalette.verdigris)
            }
        }
    }
}

struct InkPrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(InkPalette.paper)
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 48)
            .background(InkPalette.ink, in: Capsule())
        }
        .buttonStyle(PressableButtonStyle())
    }
}
