import SwiftUI

@available(iOS 13, *)
public struct SimpleRoute<State, Body, EnvironmentObjectDependency>: Route where Body: View, EnvironmentObjectDependency: ObservableObject {
    @usableFromInline
    var _prepareState: (EnvironmentObjectDependency) -> State
    
    @usableFromInline
    var _body: (State) -> Body
    
    @inlinable
    public init(dependency: EnvironmentObjectDependency.Type = EnvironmentObjectDependency.self, prepareState: @escaping (EnvironmentObjectDependency) -> State, body: @escaping (State) -> Body) {
        _prepareState = prepareState
        _body = body
    }
    
    @inlinable
    public init(prepareState: @escaping () -> State, body: @escaping (State) -> Body) where EnvironmentObjectDependency == VoidEnvironmentObject {
        _prepareState = { _ in prepareState() }
        _body = body
    }
    
    @inlinable
    public init(body: @escaping () -> Body) where State == Void, EnvironmentObjectDependency == VoidEnvironmentObject {
        _prepareState = { _ in () }
        _body = { _ in body() }
    }
    
    @inlinable
    public func prepareState(environmentObject: EnvironmentObjectDependency) -> State {
        _prepareState(environmentObject)
    }
    
    @inlinable
    public func body(state: State) -> Body {
        _body(state)
    }
}

@available(iOS 13, *)
public class VoidEnvironmentObject: ObservableObject {}
