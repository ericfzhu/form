import SwiftData
import SwiftUI
import UIKit

enum InkPalette {
    // These values mirror the canvas palette used by the website.
    static let ink = Color(red: 38 / 255, green: 41 / 255, blue: 43 / 255)
    static let softInk = Color(red: 91 / 255, green: 92 / 255, blue: 87 / 255)
    static let paper = Color(red: 243 / 255, green: 241 / 255, blue: 233 / 255)
    static let raisedPaper = paper
    static let washedInk = Color(red: 181 / 255, green: 181 / 255, blue: 174 / 255)
    static let plum = Color(red: 104 / 255, green: 72 / 255, blue: 88 / 255)
    static let verdigris = Color(red: 87 / 255, green: 112 / 255, blue: 103 / 255)
    static let steel = Color(red: 73 / 255, green: 96 / 255, blue: 115 / 255)
    static let mist = Color(red: 222 / 255, green: 229 / 255, blue: 228 / 255)
    static let mineral = verdigris
    static let cinnabar = plum
    static let bronze = washedInk
    static let acid = steel
}

enum AtelierType {
    static func script(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .monospaced)
    }
}

struct PaperSurface: View {
    var body: some View { InkPalette.paper }
}

struct PaperBackground: View {
    var body: some View {
        ZStack {
            InkPalette.paper
            Image("xuan-paper")
                .resizable(resizingMode: .tile)
                .blendMode(.multiply)
                .opacity(0.10)
            .accessibilityHidden(true)
        }
        .ignoresSafeArea()
    }
}

struct InkDivider: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            let midY = size.height / 2
            let segments = max(2, Int(size.width / 34))
            for index in 0...segments {
                let progress = CGFloat(index) / CGFloat(segments)
                let x = progress * size.width
                let y = midY
                    + sin(progress * .pi * 5.2) * 0.42
                    + sin(progress * .pi * 13.7) * 0.18
                index == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
            }
            context.stroke(
                path,
                with: .color(InkPalette.softInk.opacity(0.28)),
                style: StrokeStyle(lineWidth: 0.75, lineCap: .round, lineJoin: .round)
            )
        }
            .frame(height: 4)
            .accessibilityHidden(true)
    }
}

struct FieldThread: View {
    var color = InkPalette.washedInk.opacity(0.55)

    var body: some View {
        Canvas { context, size in
            var path = Path()
            let segments = max(2, Int(size.height / 34))
            for index in 0...segments {
                let progress = CGFloat(index) / CGFloat(segments)
                let x = size.width / 2
                    + sin(progress * .pi * 4.7) * 0.44
                    + sin(progress * .pi * 11.3) * 0.16
                let y = progress * size.height
                index == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
            }
            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: 0.75, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(width: 4)
        .accessibilityHidden(true)
    }
}

struct ClassicalRule: View {
    var body: some View {
        InkDivider()
    }
}

struct RawScreenTitle: View {
    let index: String
    let title: String
    var detail: String = ""
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 36

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
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
            InkDivider()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(detail.isEmpty ? title : "\(title), \(detail)")
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct FieldSectionTitle: View {
    let title: String
    var detail: String = ""

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title.lowercased())
                .font(AtelierType.script(21))
                .foregroundStyle(InkPalette.ink)
            Spacer()
            if !detail.isEmpty {
                Text(detail.lowercased())
                    .font(AtelierType.script(13))
                    .foregroundStyle(InkPalette.softInk.opacity(0.62))
            }
        }
        .frame(minHeight: 40)
        .overlay(alignment: .bottom) { InkDivider() }
    }
}

struct RawSectionHeader: View {
    let index: String
    let title: String
    var trailing: String = ""

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title.lowercased())
                .font(AtelierType.script(20))
            Spacer()
            if !trailing.isEmpty {
                Text(trailing.lowercased())
                    .font(AtelierType.script(13))
                    .foregroundStyle(InkPalette.softInk.opacity(0.68))
            }
        }
        .padding(.horizontal, 2)
        .frame(minHeight: 48)
        .overlay(alignment: .bottom) { InkDivider() }
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
                .font(AtelierType.script(20))
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
        .overlay(alignment: .bottom) { InkDivider() }
    }
}

private struct InkCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.clear)
            .overlay(alignment: .bottom) { InkDivider().opacity(0.72) }
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
            .foregroundStyle(InkPalette.ink)
            .padding(.horizontal, 7)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .overlay(alignment: .top) { InkDivider() }
            .overlay(alignment: .bottom) { InkDivider() }
        }
        .buttonStyle(PressableButtonStyle())
    }
}
