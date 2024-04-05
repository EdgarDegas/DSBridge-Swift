[^1]

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://github.com/EdgarDegas/DSBridge-Swift/assets/12840982/ed61fed2-a356-4772-a0b0-38a39bd0d5a9">
  <source media="(prefers-color-scheme: light)" srcset="https://github.com/EdgarDegas/DSBridge-Swift/assets/12840982/8c1ad005-6866-4ea3-a690-d33e564fde57">
  <img alt="Logo" src="https://github.com/EdgarDegas/DSBridge-Swift/assets/12840982/e1e1d27c-efe4-401d-87a2-3b5c371e0af9">
</picture>
[^1]: Designed by [Freepik](https://freepik.com)

DSBridge-Swift 是 [DSBridge-iOS](https://github.com/wendux/DSBridge-IOS) 的一个 Swift 版 fork。它允许开发者在原生和 JavaScript 之间调用彼此的方法。

# 集成方式

DSBridge 是一个三端可用的 JavaScript Bridge。

本仓库为 iOS 端的 Swift 版本，**支持通过 Swift Package Manager 集成**。

> Swift Package Manager 完全可以与 CocoaPods 等混合使用，没有兼容问题。若只能使用 CocoaPods，请转至 [Objective-C 实现的 DSBridge-iOS](https://github.com/wendux/DSBridge-IOS)。

Android 端集成方式见 [DSBridge-Android](https://github.com/wendux/DSBridge-Android)。

你可以通过 CDN 引入 JavaScript 代码（或下载 JS 文件并添加到工程中以避免网络问题）：
```html
<script src="https://cdn.jsdelivr.net/npm/dsbridge@3.1.4/dist/dsbridge.js"></script>
```

也可以使用 npm 安装：

```shell
npm install dsbridge@3.1.4
```

# 使用

## 简介

首先，在你的视图中使用 `DSBridge.WebView` 而非 `WKWebView`：

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

声明一个类型并加上 `@Exposed` 注释，它便成了一个 `Interface`，其下的方法将被暴露给 JavaScript：

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

对于不想暴露的方法，加上 `@unexposed` 注释：

```swift
@Exposed
class MyInterface {
    @unexposed
    func localMethod()
}
```

除了 `class`，你也可以声明 `struct` 或者 `enum` 作为 `Interface`：

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

最后，将接口添加到 `WebView` 中。

注意，第二个参数 `by` 传入的是命名空间，传入 `nil` 或空字符串，则该 `Interface` 没有命名空间。同时只能有一个没有命名空间的 `Interface`，每个命名空间下同时也只能有一个 `Interface`，如果重复则后来者居上：

```swift
webView.addInterface(MyInterface(), by: nil)  // `nil` works the same as ""
webView.addInterface(EnumInterface.onStreet, by: "street")
webView.addInterface(EnumInterface.inSchool, by: "school")
```

之后，你就可以从 JavaScript 调用这些方法了，注意在方法名前加上命名空间：

```javascript
bridge.call('addingOne', 5)  // returns 6
bridge.call('street.getName')  // returns Heisenberg
bridge.call('school.getName')  // returns Walter White
```

>  你完全可以声明多层的命名空间，如 `a.b.c` 等。

声明异步方法略有不同，方法的最后一个参数必须是一个闭包，你将通过这个闭包来返回你的响应：

```swift
@Exposed
class MyInterface {
    func asyncStyledFunction(callback: (String) -> Void) {
        callback("Async response")
    }
}
```

从 JavaScript 调用时，对应地，将回调函数传入：

```javascript
bridge.call('asyncStyledFunction', function(v) { console.log(v) });
// ""
// Async response
```

可以看到，调用之后会立刻收到一个空字符串返回，这是符合期望的。而我们的异步返回值则是在传入的回调 function 中获得的。

DSBridge 提供了一次调用、多次返回的功能，你只需要将给闭包增加一个 `Bool` 类型的参数，这个参数意味着是否已完成。响应时，若传入 `false`，表示未完成，以后你还可以再次调用这个闭包来发送响应；若传入 `true`，JS 端将删除回调函数，即不再接收对于本次调用的响应：

```swift
@Exposed
class MyInterface {
    func asyncFunction(
        input: Int, 
        completion: @escaping (Int, Bool) -> Void
    ) {
        // 传入 `false` 要求 JS 保留回调函数
        completion(input + 1, false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion(input + 2, false)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            // 传入 `true` 则 JS 将删除回调函数
            completion(input + 3, true)
        }
        // 之后再调用也不会有效果了
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            completion(input + 4, true)
        }
    }
}
```

JavaScript 调用：

```javascript
bridge.call('asyncFunction', 1, function(v) { console.log(v) });
// ""
// 2
// 3
// 4
```

## `Interface` 声明规则

### 支持的 `Interface` 类型

你可以将 `Interface` 声明为 `class`、`struct` 或 `enum`。暂未支持 `actor`，欢迎大家的想法。

### 支持的数据类型

你可以发送或接收这些类型的数据：

- String
- Int, Double 等（与 NSNumber 无缝转换的类型）
- Bool
- 标准的 JSON 顶层对象：
    - Dictionary，必须可编码为 JSON
    - Array，必须可编码为 JSON

### 支持的方法声明

DSBridge-Swift 无视 `Interface` 中的方法的参数名，无论调用名还是内部名，因此你可以使用任意的参数名。

#### 同步方法

关于参数，同步方法只能：

- 有 1 个参数，类型符合上述”支持的数据类型“

- 没有参数

关于返回值，同步方法可以：

- 有返回值，类型符合上述”支持的数据类型“
- 没有返回值

为了简便，使用 `Allowed` 代指上面说的”支持的数据类型“：

```swift
func name()
func name(Allowed)
func name(Allowed) -> Allowed
```

#### 异步方法

异步方法可以有 1 个或 2 个参数，不允许有返回值。

如果有 2 个参数，第 1 个参数类型必须符合上述”支持的数据类型“。

方法的最后一个参数必须是闭包，返回 `Void`。关于参数，闭包只能：

- 有 1 个参数，类型符合上述”支持的数据类型“
- 有 2 个参数，第 1 个类型符合上述”支持的数据类型“，第 2 个必须是 `Bool` 类型

```swift
typealias Completion = (Allowed) -> Void
typealias RepeatableCompletion = (Allowed, Bool) -> Void

func name(Completion)
func name(RepeatableCompletion)
func name(Allowed, Completion)
func name(Allowed, RepeatableCompletion)
```

闭包可以是 `@escaping` 的；如果不是的话，请注意，你的方法应当快速执行、立即返回，否则将会阻塞主线程。

# 与 DSBridge-iOS 的不同

## 无感的 `WKWebView` 体验

为了实现 `WKWebView` 的 `uiDelegate`，使用原来的 DSBridge-iOS 时，开发者必须设置 `dsuiDelegate`，而非 `uiDelegate`；而使用 DSBridge-Swift，你可以直接设置 `uiDelegate`。

原来的 `dsuiDelegate` 无法对新推出的方法生效，比如 iOS 16.4 推出的新 API：

```swift
@available(iOS 16.4, *)
func webView(
    _ webView: WKWebView,
    willPresentEditMenuWithAnimator animator: any UIEditMenuInteractionAnimating
) {
        
}
```

即便你设置了 `dsuiDelegate` 并且实现了这个方法，在网页选中文本、弹出编辑栏的时候，这个方法仍然不会被调用。原因是按照 DSBridge-iOS 的设计，`WKUIDelegate` 中任何一个方法都必须由库的作者先在 `DWKWebView` 中实现一遍，它才能转发给 `dsuiDelgate`。

甚至它默认的弹窗实现使用 `UIAlertView` 现在还会导致崩溃。

DSBridge-Swift 选择不站在开发者和 `WKWebView` 之间。DSBridge-Swift 以一种中间人的形式捕获了来自 JS 的调用，而将其他的代理方法转发给开发者自己设置的 `WebView.uiDelegate`，由开发者自己决定是否实现、怎么实现。

因此 DSBridge-Swift 中没有 `dsuiDelegate` ，请直接设置 `uiDelegate`。

## 静态，而非动态

在原来的 DSBridge-iOS 中，你的 JavaScript Object 必须是 `NSObject` 子类，且每个你要暴露给 JavaScript 的方法都需要标注 `@objc`；而在 DSBridge-Swift 中，你可以用纯 Swift 的类而不需要继承 `NSObject`，甚至可以使用 `struct` 和 `enum`。

## 可定制化

DSBridge-Swift 基于一种高度可定制化的设计，允许你自由修改它的任意部分，甚至无需修改它的源码即足以应对 JavaScript 端的更新。详情参照后文“基本原理和开闭原则”。

## API 变化

### 新增

一个新的原生调用 JavaScript 的方法，你可以传入你期望的返回值的类型，方法返回 `Result<T, Error>` 而不是 `Any`：

```swift
call<T>(
    _: String, 
    with: [Any], 
    thatReturns: T.Type, 
    completion: @escaping (Result<T, any Swift.Error>) -> Void
)
```

### 重命名

- `callHandler` 现在重命名为 `call`
- 移除 `setJavascriptCloseWindowListener`，请直接给 `dismissalHandler` 赋值
- `addJavascriptObject` 改名为 `addInterface`
- `removeJavascriptObject` 改名为 `removeInterface`

### 移除

- 移除了 `loadUrl(_: String)`，如果有需要请自行声明

- 移除了 `onMessage`，原库在注释中禁止开发者调用这个方法，希望你没有调用
- 综上“无感的 `WKWebView` 体验”所述，移除了：
    - `dsuiDelegate`
    - `disableJavascriptDialogBlock`
    - `customJavascriptDialogLabelTitles`
    - 所有 `WKUIDelegate` 的方法的实现

### 暂未实现

- debug 模式

# 基本原理和开闭原则

DSBridge-Swift 的 `DSBridge.WebView` 中几乎没有逻辑，逻辑被移放到了作为中枢的拱心石 `Keystone` 中。

> **拱心石**（英语：Keystone），是砖石拱门顶上的楔形石头以及圆形石头。这些石块是施工过程中最后一块安放的石头，它主要能将所有的石头固定在位置上。 – [维基百科](https://zh.wikipedia.org/wiki/拱顶石)

这是使用 DSBridge-Swift 时，JavaScript 调用 Native 的同步方法的过程：

<img src="https://github.com/EdgarDegas/DSBridge-Swift/blob/main/assets/image-20240326210400582.png?raw=true" width="500" />

接下来，我们将介绍其中各个环节的可定制性，你会了解到 DSBridge-Swift 是如何实践开闭原则的。

## 解析来自 JavaScript 的调用

你可以修改 `Keystone` 的 `jsonSerializer` 和/或 `methodResolver`，这两个对象负责将来自 JavaScript 的调用转化为 `IncomingInvocation`（DSBridge-Swift 对于来自 JS 的调用的封装）。

想用 SwiftyJSON 或者 HandyJSON？想修改传参格式？没问题，修改 `jsonSerializer` 就行：

```swift
import class DSBridge.Keystone
// ...
(webView.keystone as! Keystone).jsonSerializer = MyJSONSerializer()
// ...
```

还有比如 DSBridge-Swift 仅在开发环境中打印 JSON 序列化报错的详情；生产环境中，具体的对象或 JSON 字符串会被替换为`*hashed*`或者一个空对象。如果你希望改变这一行为，你可以自己定义错误类型，而不使用 `DSBridge.Error.JSON` 之下的那些。

`methodResolver` 更为简单，它只是从诸如 `street.getName` 的字符串中提取出命名空间和方法名。

```swift
(webView.keystone as! Keystone).methodResolver = MyMethodResolver()
```

## 派发 Invocation

在将被封装为 Invocation 后，调用来到了 Dispatcher。

`Keystone.invocationDispatcher` 负责管理所有你注册的 `Interface`，并负责将 `IncomingInvocation` 派发给它的目标 `Interface`。

你可以替换它，提供你自己的实现：

```swift
(webView.keystone as! Keystone).invocationDispatcher = MyInvocationDispatcher()
```

## 执行 JavaScript

为了解释如何自定义 JavaScript 执行，这是 JavaScript 异步调用的过程。

调用抵达 Dispatcher 之前的过程与同步方法无异。当 Dispatcher 接收到异步调用时，它会立刻返回一个空的响应，以使网页可以继续运行。至此，同步的返回链条已经断开了。

<img src="https://github.com/EdgarDegas/DSBridge-Swift/blob/main/assets/image-20240326210427127.png?raw=true" width="500" />

与此同时，它把调用派发给 `Interface`。由于同步返回的通道已经关闭，DSBridge-Swift 将通过执行 JavaScript 的方式发送响应数据：

<img src="https://github.com/EdgarDegas/DSBridge-Swift/blob/main/assets/image-20240326210448065.png?raw=true" width="500" />

`JavaScriptEvaluator` 负责管理所有发向 JavaScript 的消息，仿照 DSBridge-iOS，它每 50ms 才执行一次 JavaScript 脚本，避免执行过于频繁，被 iOS “丢包”。原来的 DSBridge-iOS 只针对回调（响应来自 JS 的异步调用）做了优化，[Native 主动调用仍然会出现丢包](https://github.com/wendux/DSBridge-IOS/issues/154)；DSBridge-Swift 则对于 Native 的主动调用也做了等待队列。

如果你需要做进一步的优化，或者不想要这样的优化，还原本来的体验，你完全可以将 `Keystone.javaScriptEvaluator` 替换掉。

## 拱心石

有了上面这样的可扩展性，你甚至可以修改 JS 端的代码，而无需修改 DSBridge-Swift 的源码。

在这之上，你甚至可以重新定义自己的拱心石，完全替换掉从接收来自 JS 的原始字符串之后的所有逻辑。这需要你实现 `DSBridge.KeystoneProtocl`，你可以利用或舍弃 DSBridge-Swift 中的现成实现，打造一个完全不同的 Bridge。
