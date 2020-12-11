#if canImport(UIKit)
import UIKit
import SwiftUI

@available(iOS 13, macOS 10.15, *)
final class RouteHost: Hashable {
    
    // MARK: State
    
    let root: AnyView
    weak var hostingController: UIHostingController<AnyView>?
    
    // MARK: Init
    
    init(root: AnyView, hostingController: UIHostingController<AnyView>) {
        self.root = root
        self.hostingController = hostingController
    }
    
    func reset() {
        hostingController?.rootView = root
    }
    
    // MARK: Equatable / hashable
    
    static func == (lhs: RouteHost, rhs: RouteHost) -> Bool {
        lhs === rhs
    }
    
    func hash(into hasher: inout Hasher) {
        ObjectIdentifier(self).hash(into: &hasher)
    }
}

@available(iOS 13, macOS 10.15, *)
extension Set where Element == RouteHost {
    mutating func garbageCollect() {
        self = self.filter { $0.hostingController != nil }
    }
}

public struct RouteViewIdentifier: Hashable {
    public static let none = RouteViewIdentifier(id: 0)
    private static var id = 1
    let id: Int
    
    private init(id: Int) {
        self.id = id
    }
    
    init() {
        self.id = Self.id
        Self.id += 1
    }
}

/// A `Router` implementation that pushes routed views onto a `UINavigationController`.
@available(iOS 13, *)
open class UINavigationControllerRouter: Router {
    public let navigationController: UINavigationController
    let parentRouter: (Router, PresentationContext)?
    
    /// key: `ObjectIdentifier` of the `HostingController`
    private var routeHosts: [RouteViewIdentifier: RouteHost] = [:]
    
    /// 🌷
    /// - Parameter navigationController: The navigation controller to use for routing.
    public init(navigationController: UINavigationController = UINavigationController()) {
        self.navigationController = navigationController
        self.parentRouter = nil
    }
    
    public init<Root>(navigationController: UINavigationController = UINavigationController(), root: Root, _ environmentObject: Root.EnvironmentObjectDependency, parent: (Router, PresentationContext)? = nil) where Root: Route {
        self.navigationController = navigationController
        self.parentRouter = parent
        navigate(to: root, environmentObject, using: DestinationPresenter())
    }
    
    public init<Root>(navigationController: UINavigationController = UINavigationController(), root: Root) where Root: Route, Root.EnvironmentObjectDependency == VoidObservableObject {
        self.navigationController = navigationController
        self.parentRouter = nil
        navigate(to: root, .init(), using: DestinationPresenter())
    }
    
    // MARK: Root view replacement
    
    open func replaceRoot<Target: Route, ThePresenter: Presenter>(with target: Target, _ environmentObject: Target.EnvironmentObjectDependency, using presenter: ThePresenter) {
        unimplemented()
//        let viewController = makeViewController(for: target, environmentObject: environmentObject, using: presenter)
//        navigationController.viewControllers = [viewController]
    }
    
    // MARK: Navigation
    
    private func topLevelRouteHost() -> RouteHost? {
        for controller in navigationController.viewControllers.reversed() {
            if let routeHost = routeHosts.values.first(where: { $0.hostingController === controller }) {
                return routeHost
            }
        }
        
        return nil
    }
    
    /// - note: Not an implementation of the protocol requirement.
    @discardableResult
    open func navigate<Target, ThePresenter>(to target: Target, _ environmentObject: Target.EnvironmentObjectDependency, using presenter: ThePresenter, source: RouteViewIdentifier?) -> RouteViewIdentifier where Target : Route, ThePresenter : Presenter {
        func topLevelRouteHostOrNew() -> (RouteHost, UIHostingController<AnyView>) {
            if let topHost = topLevelRouteHost(), let viewController = topHost.hostingController {
                return (topHost, viewController)
            } else {
                debugPrint("⚠️ Presenting route host for replacing presenter \(presenter) as root view, because an eligible view for presentation was not found.")
                
                let id = RouteViewIdentifier()
                let viewController = makeViewController(for: target, environmentObject: environmentObject, using: presenter, routeViewId: id)
                let routeHost = registerHostingController(hostingController: viewController, byRouteViewId: id)
                return (routeHost, viewController)
            }
        }
        
        let targetRouteViewId = RouteViewIdentifier()
        
        if !presenter.replacesParent { // Push 💨
            let viewController = makeViewController(for: target, environmentObject: environmentObject, using: presenter, routeViewId: targetRouteViewId)
            registerHostingController(hostingController: viewController, byRouteViewId: targetRouteViewId)
            navigationController.pushViewController(viewController, animated: true)
        } else {
            let host: RouteHost
            let hostingController: UIHostingController<AnyView>
            
            if let source = source {
                if let theHost = routeHosts[source], let viewController = theHost.hostingController {
                    host = theHost
                    hostingController = viewController
                } else {
                    debugPrint("⚠️ Trying to present on top of nonexisting source")
                    
                    (host, hostingController) = topLevelRouteHostOrNew()
                }
            } else {
                (host, hostingController) = topLevelRouteHostOrNew()
            }
            
            let state = target.prepareState(environmentObject: environmentObject)
            var isPresented = true
            let presentationContext = PresentationContext(
                parent: host.root,
                destination: AnyView(adjustView(target.body(state: state), environmentObject: environmentObject, routeViewId: targetRouteViewId)),
                isPresented: Binding(
                    get: {
                        isPresented
                    },
                    set: { newValue in
                        isPresented = newValue
                    }
                )
            ) { [unowned self] rootRoute, presentationContext in
                self.makeChildRouterView(rootRoute: rootRoute, presentationContext: presentationContext)
            }
            
            hostingController.rootView = AnyView(presenter.body(with: presentationContext))
        }
        
        return targetRouteViewId
    }
    
    public func dismissUpTo(routeMatchesId id: RouteViewIdentifier) {
        guard let hostingController = routeHosts[id]?.hostingController else {
            if let (parentRouter, presentationContext) = parentRouter {
                presentationContext.isPresented = false
                DispatchQueue.main.async {
                    parentRouter.dismissUpTo(routeMatchesId: id)
                }
                return
            }
            
            debugPrint("⚠️ Cannot dismiss route that's not in the hierarchy")
            return
        }
        
        navigationController.popToViewController(hostingController, animated: true)
    }
    
    public func dismissUpToIncluding(routeMatchingId id: RouteViewIdentifier) {
        guard let hostingController = routeHosts[id]?.hostingController else {
            if let (parentRouter, presentationContext) = parentRouter {
                presentationContext.isPresented = false
                DispatchQueue.main.async {
                    parentRouter.dismissUpTo(routeMatchesId: id)
                }
                return
            }
            
            debugPrint("⚠️ Cannot dismiss route that's not in the hierarchy")
            return
        }
        
        if let viewControllerIndex = navigationController.viewControllers.firstIndex(of: hostingController) {
            if viewControllerIndex == 0 {
                debugPrint("⚠️ Dismissal of root route is not possible")
                navigationController.popToRootViewController(animated: true)
                return
            }
            
            let viewControllerBefore = navigationController.viewControllers[viewControllerIndex - 1]
            
            navigationController.popToViewController(viewControllerBefore, animated: true)
        } else {
            debugPrint("Dismissal of route whose view controller is not presented by the navigation controller")
        }
    }
    
    // MARK: Customisation points
    
    /// Generate the view controller (usually a hosting controller) for the given destination.
    /// - Parameter destination: A destination to route to.
    /// - Returns: A view controller for showing `destination`.
    open func makeViewController<Target: Route, ThePresenter: Presenter>(for target: Target, environmentObject: Target.EnvironmentObjectDependency, using presenter: ThePresenter, routeViewId: RouteViewIdentifier) -> UIHostingController<AnyView> {
        let state = target.prepareState(environmentObject: environmentObject)
        let context = PresentationContext(parent: EmptyView(), destination: target.body(state: state), isPresented: isPresentedBinding(forRouteMatchingId: routeViewId)) { [unowned self] rootRoute, presentationContext in
            self.makeChildRouterView(rootRoute: rootRoute, presentationContext: presentationContext)
        }
        
        return makeHostingController(
            // TODO: Pass source view
            rootView: adjustView(
                presenter.body(with: context),
                environmentObject: environmentObject,
                routeViewId: routeViewId
            )
        )
    }
    
    func adjustView<Input: View, Dependency: ObservableObject>(_ view: Input, environmentObject: Dependency, routeViewId: RouteViewIdentifier) -> some View {
        view
            .environmentObject(VoidObservableObject())
            .environmentObject(environmentObject)
            .environment(\.routeViewId, routeViewId)
    }
    
    /// Takes a `View` and creates a hosting controller for it.
    ///
    /// If you need to add any additional customisations (for example, modifiers) to all views that you navigate to, this is the method you probably want to override.
    open func makeHostingController<Root: View>(rootView: Root) -> UIHostingController<AnyView> {
        return UIHostingController(rootView: AnyView(rootView.environment(\.router, self)))
    }
    
    @discardableResult
    func registerHostingController(hostingController: UIHostingController<AnyView>, byRouteViewId routeViewId: RouteViewIdentifier) -> RouteHost {
        assert(!routeHosts.values.contains { $0.hostingController === hostingController })
        
        let routeHost = RouteHost(root: hostingController.rootView, hostingController: hostingController)
        routeHosts[routeViewId] = routeHost
        
        return routeHost
    }
    
    open func makeChildRouterView<RootRoute: Route>(
        rootRoute: RootRoute,
        presentationContext: PresentationContext
    ) -> AnyView where RootRoute.EnvironmentObjectDependency == VoidObservableObject {
        let router = UINavigationControllerRouter(
            root: rootRoute,
            VoidObservableObject(),
            parent: (self, presentationContext)
        )
        return AnyView(UINavigationControllerRouterView(router: router))
    }
    
    public func isPresenting(routeMatchingId id: RouteViewIdentifier) -> Bool {
        guard let viewController = routeHosts[id]?.hostingController else {
            return false
        }
        
        return navigationController.viewControllers.contains(viewController)
    }
    
    private func isPresentedBinding(forRouteMatchingId id: RouteViewIdentifier) -> Binding<Bool> {
        Binding(
            get: { [weak self] in
                self?.isPresenting(routeMatchingId: id) ?? false
            },
            set: { [weak self] newValue in
                if !newValue {
                    self?.dismissUpToIncluding(routeMatchingId: id)
                }
            }
        )
    }
}
#endif
