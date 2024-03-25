//
//  File.swift
//  
//
//  Created by iMoe Nya on 2024/3/20.
//

import WebKit

public typealias JSCallback = (_ result: String, _ complete: Bool) -> Void

open class WebView: WKWebView {
    open override var uiDelegate: (any WKUIDelegate)? {
        get {
            innerUIDelegate
        }
        set {
            innerUIDelegate.designatedDelegate = newValue
        }
    }
    
    open var dismissalHandler: (() -> Void)?
    
    private let jsonSerializer: any JSONSerializing
    private let jsInvocationDispatcher: any JSInvocationDispatching
    private let methodResolver: any MethodResolving
    
    private lazy var predefinedInterfaceForJS = 
        PredefinedInterfaceForJS
    { [weak self] invocation in
        self?.handlePredefinedInvocation(invocation) ?? Void()
    }
    
    open lazy var javaScriptEvaluator: any JavaScriptEvaluating =
        JavaScriptEvaluator { [weak self] script in
            self?.evaluateJavaScript(script)
        }
    
    open lazy var innerUIDelegate = UIDelegate(
        jsonSerializer: jsonSerializer,
        invocationHandler: jsInvocationDispatcher,
        methodResolver: methodResolver,
        evaluationHandler: { [weak self] in
            guard let self else { return }
            javaScriptEvaluator.evaluate($0)
        }
    )
    
    open var logger: ErrorLogging = ErrorLogger.shared {
        didSet {
            innerUIDelegate.logger = logger
        }
    }
    
    public init(
        configuration: WKWebViewConfiguration = WKWebViewConfiguration(),
        jsInvocationHandler: JSInvocationDispatching = JSInvocationDispatcher(),
        jsonSerializer: any JSONSerializing = JSONSerializer(),
        methodResolver: any MethodResolving = MethodResolver()
    ) {
        self.jsInvocationDispatcher = jsInvocationHandler
        self.jsonSerializer = jsonSerializer
        self.methodResolver = methodResolver
        super.init(frame: .zero, configuration: configuration)
        jsInvocationHandler.addInterface(
            predefinedInterfaceForJS,
            by: PredefinedInterfaceForJS.namespace
        )
    }
    
    required public init?(coder: NSCoder) {
        jsInvocationDispatcher = JSInvocationDispatcher()
        jsonSerializer = JSONSerializer()
        methodResolver = MethodResolver()
        super.init(coder: coder)
        jsInvocationDispatcher.addInterface(
            predefinedInterfaceForJS,
            by: PredefinedInterfaceForJS.namespace
        )
    }
    
    open func loadURL(_ url: URL) {
        
    }
    
    /// Call JavaScript handler.
    open func callHandler(
        _ methodName: String,
        arguments: Any?,
        completion: ((Any) -> Void)? = nil
    ) {
        do {
            let encoded = if let arguments {
                try jsonSerializer.serialize(arguments)
            } else {
                ""
            }
            javaScriptEvaluator.call(methodName, with: encoded) {
                completion?($0)
            }
        } catch {
            
        }
    }
    
    ///Add a JavaScript Object to dsBridge with namespace.
    ///- Parameters:
    ///  - object: Object which implemented the JavaScript interfaces.
    ///  - namespace: If empty, the object have no namespace.
    open func addJavaScriptObject(
        _ object: Any,
        namespace: String?
    ) {
        
    }
    
    /// Remove the JavaScript Object with the supplied namespace.
    open func removeJavaScriptObject(_ namespace: String?) {
        
    }
    
    /// Test whether the handler exist in JavaScript.
    open func hasJavaScriptMethod(
        _ handlerName: String,
        methodExistCallback: ((Bool) -> Void)?
    ) {
        
    }
    
    /// Set debug mode. if in debug mode, some errors will be prompted by a dialog
    /// and the exception caused by the native handlers will not be captured.
    open func setDebugMode(_ debug: Bool) {
        
    }
    
    open func disableJavaScriptDialogBlock(_ disable: Bool) {
        
    }
    
    /// custom the  label text of  JavaScript dialog that includes alert/confirm/prompt.
    open func customJavaScriptDialogLabelTitles(_ dic: [AnyHashable: Any]?) {
        
    }
    
    func handlePredefinedInvocation(
        _ predefinedInvocation: PredefinedJSInvocation
    ) -> Any {
        switch predefinedInvocation {
        case .callback(let callback):
            javaScriptEvaluator.handleCallback(callback)
        case .initialize:
            javaScriptEvaluator.initialize()
        case .close:
            dismissalHandler?()
        case .hasMethod(let rawMethod):
            do {
                let method = try methodResolver.resolveMethodFromRaw(
                    rawMethod
                )
                let result = jsInvocationDispatcher.hasMethod(method)
                return result
            } catch {
                logger.logMessage(
                    "Failed to resolve method from text: \(rawMethod).",
                    at: .debug
                )
                return false
            }
        }
        return Void()
    }
}
