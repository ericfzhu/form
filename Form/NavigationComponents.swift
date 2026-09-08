import SwiftUI
import UIKit

struct DemonstrationImage: View {
    let assetName: String
    var outlined = true

    var body: some View {
        Image("paper-" + PaperArtwork.name(for: assetName))
            .resizable().scaledToFit()
            .accessibilityHidden(true)
    }
}

struct PressableButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.84 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private struct LeadingEdgeSwipeModifier: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        content.overlay(alignment: .leading) {
            Color.clear
                .frame(width: 36)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 14)
                        .onEnded { value in
                            let horizontalDistance = value.translation.width
                            let projectedDistance = value.predictedEndTranslation.width
                            guard horizontalDistance > 45,
                                  projectedDistance > 90,
                                  horizontalDistance > abs(value.translation.height) * 1.4 else { return }
                            action()
                        }
                )
                .accessibilityHidden(true)
        }
    }
}

extension View {
    func leadingEdgeSwipe(action: @escaping () -> Void) -> some View {
        modifier(LeadingEdgeSwipeModifier(action: action))
    }
}

struct InteractivePopGestureBridge: UIViewRepresentable {
    let isEnabled: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> NavigationResolverView {
        let view = NavigationResolverView()
        view.onResolve = { [weak coordinator = context.coordinator] navigationController in
            coordinator?.configure(navigationController)
        }
        return view
    }

    func updateUIView(_ view: NavigationResolverView, context: Context) {
        context.coordinator.isEnabled = isEnabled
        view.resolveNavigationController()
    }

    static func dismantleUIView(_ view: NavigationResolverView, coordinator: Coordinator) {
        coordinator.restore()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var isEnabled = false
        private weak var navigationController: UINavigationController?
        private weak var gestureRecognizer: UIGestureRecognizer?
        private var previousDelegate: UIGestureRecognizerDelegate?

        func configure(_ navigationController: UINavigationController) {
            guard let gestureRecognizer = navigationController.interactivePopGestureRecognizer else { return }
            if self.navigationController !== navigationController {
                restore()
                self.navigationController = navigationController
                self.gestureRecognizer = gestureRecognizer
                previousDelegate = gestureRecognizer.delegate
            }
            gestureRecognizer.delegate = self
            gestureRecognizer.isEnabled = isEnabled
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard isEnabled,
                  let navigationController,
                  navigationController.viewControllers.count > 1,
                  navigationController.transitionCoordinator == nil,
                  let panGesture = gestureRecognizer as? UIPanGestureRecognizer else {
                return false
            }
            let velocity = panGesture.velocity(in: panGesture.view)
            return velocity.x > 0 && velocity.x > abs(velocity.y)
        }

        func restore() {
            guard let gestureRecognizer else { return }
            if gestureRecognizer.delegate === self {
                gestureRecognizer.delegate = previousDelegate
            }
            self.gestureRecognizer = nil
            navigationController = nil
            previousDelegate = nil
        }
    }
}

final class NavigationResolverView: UIView {
    var onResolve: ((UINavigationController) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        resolveNavigationController()
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        resolveNavigationController()
    }

    func resolveNavigationController() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            var responder: UIResponder? = self
            while let current = responder {
                if let navigationController = current as? UINavigationController {
                    self.onResolve?(navigationController)
                    return
                }
                if let viewController = current as? UIViewController,
                   let navigationController = viewController.navigationController {
                    self.onResolve?(navigationController)
                    return
                }
                responder = current.next
            }
        }
    }
}


enum PaperArtwork {
    static func name(for id: String) -> String {
        switch id {
        case "barbell-back-squat", "bodyweight-squat", "squat": "squat"
        case "barbell-bench-press", "bench-press": "bench-press"
        case "seated-row": "seated-row"
        case "leg-curl": "leg-curl"
        case "barbell-romanian-deadlift", "romanian-deadlift", "rdl": "rdl"
        case "barbell-incline-press", "incline-press": "incline-press"
        case "lat-pulldown", "underhand-lat-pulldown", "pulldown": "pulldown"
        case "reverse-lunge", "split-squat": "reverse-lunge"
        case "arrive", "pause", "walk", "finished", "pages": id
        default: "pages"
        }
    }
}

struct PaperVignette: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settled = false
    let name: String
    var height: CGFloat = 220
    var body: some View {
        DemonstrationImage(assetName: name)
            .frame(maxWidth: .infinity).frame(height: height)
            .offset(y: reduceMotion || !["arrive", "pause", "finished"].contains(name) ? 0 : (settled ? 0 : 3))
            .animation(reduceMotion ? nil : .easeInOut(duration: 1.8), value: settled)
            .onAppear { settled = true }
    }
}
