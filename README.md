[^1]

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://github.com/EdgarDegas/DSBridge-Swift/assets/12840982/ed61fed2-a356-4772-a0b0-38a39bd0d5a9">
  <source media="(prefers-color-scheme: light)" srcset="https://github.com/EdgarDegas/DSBridge-Swift/assets/12840982/8c1ad005-6866-4ea3-a690-d33e564fde57">
  <img alt="Logo" src="https://github.com/EdgarDegas/DSBridge-Swift/assets/12840982/e1e1d27c-efe4-401d-87a2-3b5c371e0af9">
</picture>

[^1]: Designed by [Freepik](https://freepik.com)

DSBridge-Swift is a [DSBridge-iOS](https://github.com/wendux/DSBridge-IOS) fork in Swift. It allows developers to send method calls back and forth between Swift and JavaScript.

# Usage
First of all, use `DSBridge.WebView` instead of `WKWebView`:
```swift
import class DSBridge.WebView
class ViewController: UIViewController {
    // ......
    override func loadView() {
        view = WebView()
    }
    // ......
}
```

DSBridge-Swift does not rely on Objective-C runtime. Thus you can declare your interface with pure Swift types:
```swift

import Foundation
import typealias DSBridge.Exposed
import protocol DSBridge.ExposedInterface

@Exposed
class MyInterface {
    func returnValue() -> Int { 101 }
    @unexposed
    func localMethod()
}
```
Mark your interface `@Exposed` and that's it. Add `@unexposed` annotation to any function you don't want to expose.

If you don't need to declare it as a class, why not use a struct? Or, even further, an enum! 
```swift
@Exposed
enum EnumInterface {
    case onStreet
    case inSchool
    
    func getName() -> String {
        switch self {
        case .onStreet:
            "Heisenberg"
        case .inSchool:
            "Walter White"
        }
    }
}
```

You then add your interfaces into `DSBridge.WebView`, with or without a namespace:
```swift
webView.addInterface(Interface(), by: nil)  // `nil` works the same as ""
webView.addInterface(EnumInterface.onStreet, by: "street")
webView.addInterface(EnumInterface.inSchool, by: "school")
```

Done. You can call them from JavaScript now:
```javascript
bridge.call('returnValue')  // returns 101
bridge.call('street.getName')  // returns Heisenberg
bridge.call('school.getName')  // returns Walter White
```

Asynchronous functions are a bit more complicated. You have to use a completion handler, whose second parameter is a `Bool`.
```swift
@Exposed
class MyInterface {
    func asyncStyledFunction(callback: (String, Bool) -> Void) {
        callback("Async response", true)
    }
}
```

Call from JavaScript with a function as the last parameter:
```javascript
bridge.call('asyncStyledFunction', function(v) { console.log(v) });
// ""
// Async response
```
As you can see, there is a empty string returned. The response we sent in the interface is printed by the `function`.

OK, we send async response with the completion in its first parameter. What does the second parameter, the `Bool` do then?

The `Bool` means `isCompleted` semantically. If you pass in a `false`, you get the chance to repeatedly call it in future. Once you call it with `true`, the callback function will be deleted from the JavaScript side:
```swift
@Exposed
class MyInterface {
    func asyncFunction(input: Int, completion: @escaping (Int, Bool) -> Void) {
        // Use `false` to ask JS to keep the callback
        completion(input + 1, false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion(input + 2, false)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            // `true` to ask JS to delete the callback
            completion(input + 3, true)
        }
        // won't have any effect from now
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            completion(input + 4, true)
        }
    }
}
```

Call from JavaScript:
```javascript
bridge.call('asyncFunction', 1, function(v) { console.log(v) });
// ""
// 2
// 3
// 4
```

What will happen if we remove the `Bool` from the completion, you might ask. It won't compile. It might shock you how rough the `Exposed` macro is implemented if you click the Xcode error.
# Declaration Rules
## Allowed Interface Types
You can declare your interface as these types:
- class
- enum
- struct

  > actors are not supported yet. Please file up your ideas about it.
## Allowed Data Types
You can receive or send the following types:
- String
- Int, Double
- Bool

And standard JSON top-level objects:
- Dictionary that's encodable
- Array that's encodable

## Allowed Function Declarations
For simplicity, we use `Allowed` to represent the before-mentioned Allowed Data Types.
You can define your synchronous functions in three ways:

```swift
func name()
func name(Allowed)
func name(Allowed) -> Allowed
```
You can have at most one parameter. You can name it with anything, `func name(_ input: Int)`, `func name(using input: Int)`, or whatever you want.

For asynchronous functions:
```swift
typealias Completion = (Allowed, Bool) -> Bool
func name(Completion)
func name(Allowed, Completion)
```
You can have your completion attributed with `@ecaping` if you need it to persist longer than the function call. 

Like the parameter, you can name the completion whatever you like.
# JavaScript side
Check out [the original repo](https://github.com/wendux/DSBridge-IOS) for how to use the JavaScript DSBridge.

# Differences with DSBridge-iOS
## API Changes
### Newly added:
A new calling method that allows you to specify the expected return type and returns a `Result<T, Error>` instead of an `Any`.
```swift
call<T>(
    _: String, 
    with: [Any], 
    thatReturns: T.Type, 
    completion: @escaping (Result<T, any Swift.Error>) -> Void
)
```
### Renamed:
- `callHandler` is renamed to `call`
- `setJavascriptCloseWindowListener` to `dismissalHandler`
- `addJavascriptObject` to `addInterface`
- `removeJavascriptObject` to `removeInterface`

### Removed:
`loadUrl(_: String)` is removed. Define your own one if you need it.

`onMessage`, as a private method marked public, is removed.

The old DSBridge-iOS relay all the `WKUIDelegate` calls for you, which cause it to suffer from iOS iteration. Especially that it crashes when it tries to show the deprecated `UIAlertView`.

DSBridge-Swift, instead, makes better use of iOS Runtime features to avoid standing between you and the web view. You can set the `uiDelegate` to your own object just like what you do with the bare `WKWebView`. 

On the contrary, you'd have to do the dialog thing yourself. And all the dialog related APIs are removed, along with the `dsuiDelegate`:
- `dsuiDelegate`
- `disableJavascriptDialogBlock`
- `customJavascriptDialogLabelTitles`
- and all the `WKUIDelegate` implementations
## Other minor differences

- Does not require `NSObjectProtocol` for interfaces and `@objc` for functions.
- Debug mode not implemented yet.

# Customization

DSBridge-Swift really shines on how it allows you to customize it.
## Resolving Incoming Calls
This is how a synchronous method call comes in and returns back:

<img src="https://github.com/EdgarDegas/DSBridge-Swift/blob/main/assets/image-20240326210400582.png?raw=true" width="500" />

The `Keystone` converts raw text into an `Invocation`. You can change how it resolves raw text by changing `methodResolver` or `jsonSerializer` of `WebView.keystone`.
```swift
import class DSBridge.Keystone
// ...
(webView.keystone as! Keystone).jsonSerializer = MyJSONSerializer()
// ...
```

Your own jsonSerializer has to implement a two-method protocol `JSONSerializing`. Keep in mind that DSBridge needs it to encode the response into JSON on the way back. It's really ease, though, and you can then use SwiftyJSON or whatever you want:
```swift
struct MyJSONSerializer: JSONSerializing {
    func readParamters(
        from text: JSON?
    ) throws -> IncomingInvocation.Signature {
        
    }
    func serialize(_ object: Any) throws -> JSON {
        
    }
}
```

`methodResolver: any MethodResolving` is even easier, it's a one-method protocol. You just read a text and return a `Method`:

```swift
(webView.keystone as! Keystone).methodResolver = MyMethodResolver()
```
## Dispatching

After being resolved into an `Invocation`, the method call is sent to `Dispather`, where all the interfaces you added are registered and indexed.

You can, of course, replace the dispatcher. Then you would have to manage interfaces and dispatch calls to different interfaces in your own `InvocationDispatching` implementation.

```swift
(webView.keystone as! Keystone).invocationDispatcher = MyInvocationDispatcher()
```

## JavaScriptEvaluation

This is how an asynchronous method call works:

<img src="https://github.com/EdgarDegas/DSBridge-Swift/blob/main/assets/image-20240326210427127.png?raw=true" width="500" />

An empty response is returned immediately when it reaches the dispatcher. After that, the `Dispatcher` continues to dispatch the method call:

<img src="https://github.com/EdgarDegas/DSBridge-Swift/blob/main/assets/image-20240326210448065.png?raw=true" width="500" />

After the interface returned, the data is wrapped into an `AsyncResponse` and delivered to the JavaScript evaluator.

Guess what, you can substitute it with your own.

## Keystone
As you can see from all above, the keystone is what holds everything together.

> A keystone is a stone at the top of an arch, which [keeps](https://www.collinsdictionary.com/dictionary/english/keep "Definition of keeps") the other stones in place by its [weight](https://www.collinsdictionary.com/dictionary/english/weight "Definition of weight") and position. -- Collins Dictionary

You can change the keystone, with either a `Keystone` subclass or a completely different `KeystoneProtocol`. Either way, you will be able to use DSBridge-Swift with any JavaScript.
