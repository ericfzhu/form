import SwiftUI
import UIKit

struct DemonstrationImage: View {
    let assetName: String
    var outlined = true

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFit()
            .clipShape(Rectangle())
            .overlay {
                if outlined { Rectangle().stroke(.black.opacity(0.10), lineWidth: 1) }
            }
            .accessibilityLabel("Mosaic illustration demonstrating the exercise")
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
