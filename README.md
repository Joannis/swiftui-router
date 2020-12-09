# 🚀 SwiftUI Router

A SwiftUI package that provides routing functionality. Great for building (MVVM) SwiftUI apps where navigation is decoupled from the UI and view models. 

## 🚲 Usage

### 🔀 Basic routing

`Route` is a protocol. The package provides one basic implementation, `SimpleRoute`, which works for simple use cases.

Define your routes by extending the `Routes` type. The most basic route looks like this:

```swift
extension Routes {
  static let hello = SimpleRoute { Text("Hello! 👋") }
}
```

To navigate to this route, you can use a `RouterLink` in any SwiftUI view contained in a `Router`:

```swift
RouterLink(to: Routes.hello) {
  Text("Some link")
}
```

### 🔭 Routes and state

A common SwiftUI pattern is to bind an `ObservableObject` to your view to serve as the view model. For example, you could have a view model like this:

```swift
class EditNameViewModel: ObservableObject {
  @Published var name: String
  
  init(name: String = "") {
    self.name = name
  }
}
```

And a view like this:

```swift
struct EditNameView: View {
  @ObservedObject var viewModel: EditNameViewModel
  
  var body: some View {
      TextField("Name", text: $viewModel.name)
  }
}
```

SwiftUI Router provides a mechanism to initialise your view state. Using `SimpleRoute`, it looks like this:

```swift
extension Routes {
  static let editName = SimpleRoute(prepareState: { EditNameViewModel() }) { viewModel in
    EditNameView(viewModel: viewModel)
  }
}
```

The `prepareState` closure runs once when navigating to the route. Afterwards, the return value is used to render the view.

### Routers

Before you are able to use your defined routes, you need to initialise a router. Because `Router` is a protocol, multiple implementations (including your own) are possible. SwiftUI Router provides the `UINavigationControllerRouter` implementation, which you can use 