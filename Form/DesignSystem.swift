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
        .system(size: size, weight: .medium, design: .rounded)
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
    }
}

struct InkTextHeader: View {
    let title: String
    let leadingTitle: String
    let leadingAction: () -> Void
    var trailingTitle: String?
    var trailingAction: (() -> Void)?

    var body: some View {
        HStack(spacing: 0) {
            Button(leadingTitle, action: leadingAction)
                .font(AtelierType.script(16))
                .foregroundStyle(InkPalette.softInk)
                .frame(width: 76, height: 52)
                .buttonStyle(PressableButtonStyle())

            Text(title)
                .font(AtelierType.script(16))
                .foregroundStyle(InkPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
                .frame(maxWidth: .infinity)

            if let trailingTitle, let trailingAction {
                Button(trailingTitle, action: trailingAction)
                    .font(AtelierType.script(16))
                    .foregroundStyle(InkPalette.verdigris)
                    .frame(width: 76, height: 52)
                    .buttonStyle(PressableButtonStyle())
            } else {
                Color.clear
                    .frame(width: 76, height: 52)
                    .accessibilityHidden(true)
            }
        }
        .background { PaperSurface() }
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
                    .font(AtelierType.script(21))
                Spacer()
            }
            .foregroundStyle(InkPalette.paper)
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .background(InkPalette.ink, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(PressableButtonStyle())
    }
}
