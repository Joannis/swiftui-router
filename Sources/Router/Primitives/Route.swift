import SwiftUI

@available(iOS 13, *)
public protocol Route {
    associatedtype State
    associatedtype Body: View
    associatedtype EnvironmentObjectDependency: ObservableObject
    
    /// Runs once when navigating to a route.
    func prepareState(environmentObject: EnvironmentObjectDependency) -> State
    func body(state: State) -> Body
}

@available(iOS 13, *)
public extension Route where State == Void {
    func prepareState() -> State {
        ()
    }
}
