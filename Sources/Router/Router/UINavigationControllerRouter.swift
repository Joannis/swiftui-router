import UIKit
import SwiftUI

/// A `Router` implementation that pushes routed views onto a `UINavigationController`.
@available(iOS 13, *)
open class UINavigationControllerRouter: Router {
    public let navigationController: UINavigationController
    
    /// 🌷
    /// - Parameter navigationController: The navigation controller to use for routing.
    public init(navigationController: UINavigationController = UINavigationController()) {
        self.navigationController = navigationController
    }
    
    open func navigate<Target: Route>(to target: Target, environment: EnvironmentValues) {
        print("🚦 Navigate to \(target)")
        
        let viewController = makeViewController(for: target, environment: environment)
        navigationController.pushViewController(viewController, animated: true)
    }
    
    open func replaceRoot<Target: Route>(with target: Target, environment: EnvironmentValues) {
        print("🚦 Replace root with \(target)")
        
        let viewController = makeViewController(for: target, environment: environment)
        navigationController.viewControllers = [viewController]
    }
    
    /// Generate the view controller (usually a hosting controller) for the given destination.
    /// - Parameter destination: A destination to route to.
    /// - Returns: A view controller for showing `destination`.
    open func makeViewController<Target: Route>(for target: Target, environment: EnvironmentValues) -> UIViewController {
        let state = target.prepareState(environment: environment)
        
        return UIHostingController(
            rootView: target.body(state: state)
                .environment(\.router, self)
        )
    }
}
