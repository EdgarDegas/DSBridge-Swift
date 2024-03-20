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
    
    private let jsonSerializer: any JSONSerializing
    private let jsInvocationHandler: any JSInvocationHandling
    
    private lazy var internalInterfaceForJS = 
        InternalInterfaceForJS
    { [weak javaScriptEvaluator] callback in
        javaScriptEvaluator?.handleCallback(callback)
    }
    
    open lazy var javaScriptEvaluator: any JavaScriptEvaluating =
        JavaScriptEvaluator { [weak self] script in
            self?.evaluateJavaScript(script)
        }
    
    open lazy var innerUIDelegate = UIDelegate(
        jsonSerializer: jsonSerializer,
        invocationHandler: jsInvocationHandler,
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
        jsInvocationHandler: JSInvocationHandler = JSInvocationHandler(),
        jsonSerializer: any JSONSerializing = JSONSerializer()
    ) {
        self.jsInvocationHandler = jsInvocationHandler
        self.jsonSerializer = jsonSerializer
        super.init(frame: .zero, configuration: configuration)
        jsInvocationHandler.addInterface(
            internalInterfaceForJS,
            by: InternalInterfaceForJS.namespace
        )
    }
    
    required public init?(coder: NSCoder) {
        jsInvocationHandler = JSInvocationHandler()
        jsonSerializer = JSONSerializer()
        super.init(coder: coder)
        jsInvocationHandler.addInterface(
            internalInterfaceForJS,
            by: InternalInterfaceForJS.namespace
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
    
    /// set a listener for JavaScript closing the current page.
    open func setJavaScriptCloseWindowListener(
        _ callback: (() -> Void)?
    ) {
        
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
    
    /// private method, the developer shoudn't call this method
    func onMessage(_ msg: [AnyHashable: Any],  type: Int) {
        
    }
}
