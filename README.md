[^1]

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://github.com/EdgarDegas/DSBridge-Swift/assets/12840982/ed61fed2-a356-4772-a0b0-38a39bd0d5a9">
  <source media="(prefers-color-scheme: light)" srcset="https://github.com/EdgarDegas/DSBridge-Swift/assets/12840982/8c1ad005-6866-4ea3-a690-d33e564fde57">
  <img alt="Logo" src="https://github.com/EdgarDegas/DSBridge-Swift/assets/12840982/e1e1d27c-efe4-401d-87a2-3b5c371e0af9">
</picture>

[^1]: Designed by [Freepik](https://freepik.com)

[简体中文版](https://github.com/EdgarDegas/DSBridge-Swift/blob/main/README.zh-Hans.md)

DSBridge-Swift is a [DSBridge-iOS](https://github.com/wendux/DSBridge-IOS) fork in Swift. It allows developers to send method calls back and forth between Swift and JavaScript.

# Installation

DSBridge is available on both iOS and Android. 

This repo is a pure Swift version. You can integrate it with Swift Package Manager.

> It's totally OK to use Swift Package Manager together with CocoaPods or other tools. If Swift Package Manager is banned, use [the original Objective-C version DSBridge-iOS](https://github.com/wendux/DSBridge-IOS).

For Android, see [DSBridge-Android](https://github.com/wendux/DSBridge-Android).

You can link the JavaScript with CDN:

```html
<script src="https://cdn.jsdelivr.net/npm/dsbridge@3.1.4/dist/dsbridge.js"></script>
```

Or install with npm:

```shell
npm install dsbridge@3.1.4
```

# Usage

## Brief

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

Declare your `Interface` with the `@Exposed` annotation. All the functions will be exposed to JavaScript:
```swift
import Foundation
import typealias DSBridge.Exposed
import protocol DSBridge.ExposedInterface

@Exposed
class MyInterface {
    func addingOne(to input: Int) -> Int {
        input + 1
    }
}
```
For functions you do not want to expose, add `@unexposed` to it:

```swift
@Exposed
class MyInterface {
    @unexposed
    func localMethod()
}
```

Aside from `class`, you can declare your `Interface` in `struct` or `enum`:

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

You then add your interfaces into `DSBridge.WebView`.

The second parameter `by` specifies namespace. `nil` or an empty string indicates no namespace. There can be only one non-namespaced `Interface` at once. Also, there can be only one `Interface` under a namespace. Adding an `Interface` to an existing namespace replaces the original one.

```swift
webView.addInterface(MyInterface(), by: nil)  // `nil` works the same as ""
webView.addInterface(EnumInterface.onStreet, by: "street")
webView.addInterface(EnumInterface.inSchool, by: "school")
```

Done. You can call them from JavaScript now. Do prepend the namespace before the method names:
```javascript
bridge.call('addingOne', 5)  // returns 6
bridge.call('street.getName')  // returns Heisenberg
bridge.call('school.getName')  // returns Walter White
```

> DSBridge supports multi-level namespaces, like `a.b.c`.

Asynchronous functions are a little bit different. You have to use a completion handler to send your response:

```swift
@Exposed
class MyInterface {
    func asyncStyledFunction(callback: (String) -> Void) {
        callback("Async response")
    }
}
```

Call from JavaScript with a function accordingly:
```javascript
bridge.call('asyncStyledFunction', function(v) { console.log(v) });
// ""
// Async response
```
As you can see, there is a empty string returned. The response we sent in the interface is printed by the `function`.

DSBridge allows us to send multiple responses to a single invocation. To do so, add a `Bool` parameter to your completion. The `Bool` means `isCompleted` semantically. If you pass in a `false`, you get the chance to repeatedly call it in future. Once you call it with `true`, the callback function will be deleted from the JavaScript side:

```swift
@Exposed
class MyInterface {
    func asyncFunction(
        input: Int, 
        completion: @escaping (Int, Bool) -> Void
    ) {
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
- Int, Double (types toll-free bridged to NSNumber)
- Bool
- Standard JSON top-level objects:

    - Dictionary that's encodable

    - Array that's encodable


## Allowed Function Declarations
DSBridge-Swift ignores argument labels and parameter names of your functions. Thus you can name your parameters whatever you want.

#### Synchronous Functions

About parameters, synchronous functions can have:

- 1 parameter, which is one of the above-mentioned *Allowed Data Types*
- no parameter

About return value, synchronous functions can have:

- return value that's one of the above-mentioned *Allowed Data Types*
- no return value

For simplicity, we use `Allowed` to represent the before-mentioned Allowed Data Types.

```swift
func name()
func name(Allowed)
func name(Allowed) -> Allowed
```
#### Asynchronous Functions

Asynchronous functions are allowed to have 1 or 2 parameters and no return value.

If there are 2 parameters, the first one must be one of the above-mentioned *Allowed Data Types*.

The last parameter has to be a closure that returns nothing (i.e., `Void`). For parameters, the closure can have:

- 1 parameter, one of the above-mentioned *Allowed Data Types*
- 2 parameters, the first one is one of the above-mentioned *Allowed Data Types* and the second one is a `Bool`

```swift
typealias Completion = (Allowed) -> Void
typealias RepeatableCompletion = (Allowed, Bool) -> Void

func name(Completion)
func name(RepeatableCompletion)
func name(Allowed, Completion)
func name(Allowed, RepeatableCompletion)
```
Attribute your closure with `@ecaping` if needed. Otherwise, keep in mind that your functions run on the main thread and try not to block it.

# Differences with DSBridge-iOS

## Seamless `WKWebView` Experience

When using the old DSBridge-iOS, in order to implement `WKWebView.uiDelegate`, you'd have to set `dsuiDelegate` instead. In DSBridge-Swift, you can just set `uiDelegate`.

The old `dsuiDelegate` does not respond to new APIs, such as one that's released on iOS 16.4:

```swift
@available(iOS 16.4, *)
func webView(
    _ webView: WKWebView,
    willPresentEditMenuWithAnimator animator: any UIEditMenuInteractionAnimating
) {
        
}
```

Even if your `dsuiDelegate` does implement it, it won't get called on text selections or editing menu animations. The reason is that the old DSBridge-iOS relay those API calls to you by implementing them ahead of time and calling `dsuiDelegate` inside those implementations. This causes it to suffer from iOS iterations. Especially that it crashes when it tries to use the deprecated `UIAlertView`.

DSBridge-Swift, instead, makes better use of iOS Runtime features to avoid standing between you and the web view. You can set the `uiDelegate` to your own object just like what you do with bare `WKWebView` and all the delegation methods will work as if DSBridge is not there.

On the contrary, you'd have to do the dialog thing yourself. And all the dialog related APIs are removed, along with the `dsuiDelegate`.

## Static instead of Dynamic

When using the old DSBridge-iOS, your *JavaScript Object* has to be an `NSObject` subclass. Functions in it have to be prefixed with `@objc`. DSBridge-Swift, however, is much more Swift-ish. You can use pure Swift types like `class` or even `struct` and `enum`.

## Customizable

DSBridge-Swift provides highly customizable flexibility which allows you to change almost any part of it. You can even extends it to use it with another piece of completely different JavaScript. See section *Open / Close Principle* below.

## API Changes
### Newly added
A new calling method that allows you to specify the expected return type and returns a `Result<T, Error>` instead of an `Any`.
```swift
call<T>(
    _: String, 
    with: [Any], 
    thatReturns: T.Type, 
    completion: @escaping (Result<T, any Swift.Error>) -> Void
)
```
### Renamed
- `callHandler` is renamed to `call`
- `setJavascriptCloseWindowListener` to `dismissalHandler`
- `addJavascriptObject` to `addInterface`
- `removeJavascriptObject` to `removeInterface`

### Removed
- `loadUrl(_: String)` is removed. Define your own one if you need it

- `onMessage`, a public method that's supposed to be private, is removed

- `dsuiDelegate`
- `disableJavascriptDialogBlock`
- `customJavascriptDialogLabelTitles`
- and all the `WKUIDelegate` implementations
### Not Implemented

- Debug mode not implemented yet.

# Open / Close Principle

DSBridge-Swift has a Keystone that holds everything together.

> A keystone is a stone at the top of an arch, which keeps the other stones in place by its weight and position. -- Collins Dictionary

Here is how a synchronous method call comes in and returns back:

<img src="https://github.com/EdgarDegas/DSBridge-Swift/blob/main/assets/image-20240326210400582.png?raw=true" width="500" />

## Resolving Incoming Calls

The `Keystone` converts raw text into an `Invocation`. You can change how it resolves raw text by changing `methodResolver` or `jsonSerializer` of `WebView.keystone`.

```swift
import class DSBridge.Keystone
// ...
(webView.keystone as! Keystone).jsonSerializer = MyJSONSerializer()
// ...
```

There might be something you don't want in the built-in JSON serializer. For example it won't log details about an object or text in production environment. You can change this behavior by defining your own errors instead of using the ones defined in `DSBridge.Error.JSON`.

`methodResolver` is even easier. It simply reads a text and finds the namespace and method name:

```swift
(webView.keystone as! Keystone).methodResolver = MyMethodResolver()
```
## Dispatching

After being resolved into an `Invocation`, the method call is sent to `Dispather`, where all the interfaces you added are registered and indexed.

You can, of course, replace the dispatcher. Then you would have to manage interfaces and dispatch calls to different interfaces in your own `InvocationDispatching` implementation.

```swift
(webView.keystone as! Keystone).invocationDispatcher = MyInvocationDispatcher()
```

## JavaScript Evaluation

To explain to you how we can customize JavaScript evaluation, here's how an asynchronous invocation works.

Everything is the same before the invocation reaches the dispatcher. The dispatcher returns an empty response immediately after it gets the invocation, so that the webpage gets to continue running. From now on, the synchronous chain breaks.

<img src="https://github.com/EdgarDegas/DSBridge-Swift/blob/main/assets/image-20240326210427127.png?raw=true" width="500" />

Dispatcher sends the invocation to `Interface` at the same time. But since the way back no longer exists, DSBridge-Swift has to send the repsonse by evaluating JavaScript:

<img src="https://github.com/EdgarDegas/DSBridge-Swift/blob/main/assets/image-20240326210448065.png?raw=true" width="500" />

The `JavaScriptEvaluator` is in charge of all the messages towards JavaScript, including method calls initiated from native. The default evaluator evaluates JavaScript every 50ms to avoid getting dropped by iOS for evaluating too frequently. 

If you need further optimization or you just want the vanilla experience instead, you can simply replace the `Keystone.javaScriptEvaluator`.

## Keystone

As you can see from all above, the keystone is what holds everything together. You can even change the keystone, with either a `Keystone` subclass or a completely different `KeystoneProtocol`. Either way, you will be able to use DSBridge-Swift with any JavaScript.
