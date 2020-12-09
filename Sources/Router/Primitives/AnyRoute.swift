import SwiftUI

@available(iOS 13, *)
public struct AnyRoute: Route {
    public typealias State = Any
    public typealias Body = AnyView
    
    private var _prepareState: () -> Any
    private var _body: (Any) -> AnyView
    
    init<Source: Route>(_ source: Source) {
        _prepareState = source.prepareState
        _body = { anyState in
            guard let state = anyState as? Source.State else {
                preconditionFailure("Type-erased route of type \(Source.self) cannot compute body with mismatching state type \(type(of: anyState).self)")
            }
            
            return AnyView(
                source.body(state: state)
            )
        }
    }
    
    public func prepareState() -> Any {
        _prepareState()
    }
    
    public func body(state: Any) -> AnyView {
        _body(state)
    }
}
