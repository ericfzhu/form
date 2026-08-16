import SwiftData
import SwiftUI
import UIKit

enum InkPalette {
    static let ink = Color(red: 0.114, green: 0.102, blue: 0.082)
    static let softInk = Color(red: 0.35, green: 0.32, blue: 0.27)
    static let paper = Color(red: 0.925, green: 0.906, blue: 0.855)
    static let raisedPaper = Color(red: 0.961, green: 0.945, blue: 0.902)
    static let washedInk = Color(red: 0.68, green: 0.64, blue: 0.55)
    static let cinnabar = Color(red: 0.43, green: 0.16, blue: 0.13)
    static let bronze = Color(red: 0.50, green: 0.42, blue: 0.27)
    static let acid = bronze
}

struct PaperSurface: View {
    var body: some View { InkPalette.paper }
}

struct PaperBackground: View {
    var body: some View {
        LinearGradient(
            colors: [InkPalette.raisedPaper.opacity(0.48), InkPalette.paper],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

struct InkDivider: View {
    var body: some View {
        Rectangle()
            .fill(InkPalette.bronze.opacity(0.72))
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

struct ClassicalRule: View {
    var body: some View {
        VStack(spacing: 3) {
            Rectangle().fill(InkPalette.bronze.opacity(0.86)).frame(height: 1)
            Rectangle().fill(InkPalette.bronze.opacity(0.42)).frame(height: 1)
        }
        .accessibilityHidden(true)
    }
}

struct RawScreenTitle: View {
    let index: String
    let title: String
    var detail: String = ""
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 52

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("FORM  /  \(index)")
                Spacer()
                if !detail.isEmpty { Text(detail) }
            }
            .font(.system(.caption2, design: .serif, weight: .semibold))
            .tracking(1.8)
            .foregroundStyle(InkPalette.bronze)

            Text(title)
                .font(.system(size: titleSize, weight: .regular, design: .serif))
                .tracking(-2.2)
                .foregroundStyle(InkPalette.ink)
                .minimumScaleFactor(0.62)
                .lineLimit(1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 27)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { ClassicalRule() }
    }
}

struct RawSectionHeader: View {
    let index: String
    let title: String
    var trailing: String = ""

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(index)
                .font(.system(size: 22, weight: .regular, design: .serif))
                .foregroundStyle(InkPalette.cinnabar)
                .frame(width: 34, alignment: .leading)
            Text(title)
                .font(.system(.caption, design: .serif, weight: .semibold))
                .tracking(1.3)
            Spacer()
            if !trailing.isEmpty {
                Text(trailing).foregroundStyle(InkPalette.softInk)
            }
        }
        .font(.system(.caption2, design: .serif, weight: .semibold))
        .tracking(1.2)
        .padding(.horizontal, 2)
        .frame(height: 46)
        .overlay(alignment: .top) { ClassicalRule() }
        .overlay(alignment: .bottom) { InkDivider() }
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
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(InkPalette.ink)
                .frame(width: 76, height: 52)
                .buttonStyle(PressableButtonStyle())

            Text(title)
                .font(.system(.subheadline, design: .serif, weight: .semibold))
                .tracking(1.8)
                .foregroundStyle(InkPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
                .frame(maxWidth: .infinity)

            if let trailingTitle, let trailingAction {
                Button(trailingTitle, action: trailingAction)
                    .font(.system(.subheadline, design: .serif))
                    .foregroundStyle(InkPalette.cinnabar)
                    .frame(width: 76, height: 52)
                    .buttonStyle(PressableButtonStyle())
            } else {
                Color.clear
                    .frame(width: 76, height: 52)
                    .accessibilityHidden(true)
            }
        }
        .background { PaperSurface() }
        .overlay(alignment: .top) { InkDivider() }
        .overlay(alignment: .bottom) { ClassicalRule() }
    }
}

private struct InkCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(InkPalette.raisedPaper)
            .overlay { Rectangle().stroke(InkPalette.bronze.opacity(0.58), lineWidth: 1) }
            .shadow(color: InkPalette.ink.opacity(0.055), radius: 7, y: 3)
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
                    .font(.system(.body, design: .serif, weight: .semibold))
                    .tint(InkPalette.cinnabar)
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
                    .font(.system(.subheadline, design: .serif, weight: .semibold))
                    .tracking(1.4)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(InkPalette.paper)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(InkPalette.cinnabar)
            .overlay { Rectangle().stroke(InkPalette.bronze, lineWidth: 1) }
            .overlay {
                Rectangle().inset(by: 4)
                    .stroke(InkPalette.paper.opacity(0.32), lineWidth: 1)
            }
        }
        .buttonStyle(PressableButtonStyle())
    }
}

