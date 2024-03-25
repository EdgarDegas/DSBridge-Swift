//
//  File.swift
//  
//
//  Created by iMoe Nya on 2024/3/20.
//

import WebKit

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
    private let methodResolver: any MethodResolving
    
    private lazy var predefinedExposedInterface = 
        PredefinedInterface
    { [weak self] invocation in
        self?.handlePredefinedInvocation(invocation) ?? Void()
    }
    
    open lazy var javaScriptEvaluator: any JavaScriptEvaluating =
        JavaScriptEvaluator { [weak self] script in
            self?.evaluateJavaScript(script)
        }
    
    open lazy var innerUIDelegate = UIDelegate(
        jsonSerializer: jsonSerializer,
        methodResolver: methodResolver
    ) { [weak self] invocation in
        self?.handleIncomingInvocation(invocation) ?? Response.emptyJSON
    }
    
    open lazy var invocationDispatcher: any InvocationDispatching
        = InvocationDispatcher
    { [weak self] asyncResponse in
        
    }
    
    open var logger: ErrorLogging = ErrorLogger.shared {
        didSet {
            innerUIDelegate.logger = logger
        }
    }
    
    public init(
        configuration: WKWebViewConfiguration = WKWebViewConfiguration(),
        jsonSerializer: any JSONSerializing = JSONSerializer(),
        methodResolver: any MethodResolving = MethodResolver()
    ) {
        self.jsonSerializer = jsonSerializer
        self.methodResolver = methodResolver
        super.init(frame: .zero, configuration: configuration)
        invocationDispatcher.addInterface(
            predefinedExposedInterface,
            by: PredefinedInterface.namespace
        )
    }
    
    required public init?(coder: NSCoder) {
        jsonSerializer = JSONSerializer()
        methodResolver = MethodResolver()
        super.init(coder: coder)
        invocationDispatcher.addInterface(
            predefinedExposedInterface,
            by: PredefinedInterface.namespace
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
    
    func handleIncomingInvocation(
        _ invocation: IncomingInvocation
    ) -> JSON? {
        let response = invocationDispatcher.dispatch(invocation)
        do {
            let json = try jsonSerializer.serialize(response)
            return json
        } catch {
            logger.logError(error)
            return nil
        }
    }
    
    func handlePredefinedInvocation(
        _ predefinedInvocation: PredefinedInvocation
    ) -> Any {
        switch predefinedInvocation {
        case .handleResponseFromJS(let callback):
            javaScriptEvaluator.handleResponse(callback)
        case .initialize:
            javaScriptEvaluator.initialize()
        case .close:
            dismissalHandler?()
        case .hasMethod(let rawMethod):
            do {
                let method = try methodResolver.resolveMethodFromRaw(
                    rawMethod
                )
                let result = invocationDispatcher.hasMethod(method)
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
    
    open func deliverAsyncResponse(
        _ response: AsyncResponse
    ) {
        let functionName = response.functionName
        let data = response.data
        let completed = response.completed
        do {
            let encoded = try jsonSerializer.serialize(data)
            let deletingScript = writeDeletingScript(
                for: functionName, if: completed
            )
            evaluateJavaScript(
                writeScriptCallingBack(
                    to: functionName,
                    encodedData: encoded,
                    deletingScript: deletingScript
                )
            )
        } catch {
            logger.logError(error)
        }
        
        func writeScriptCallingBack(
            to functionName: String,
            encodedData: String,
            deletingScript: String
        ) -> String {
            """
            try {
                \(functionName)(JSON.parse(decodeURIComponent(\(encodedData))));
                \(deletingScript);
            } catch(e) {
            
            }
            """
        }
        
        func writeDeletingScript(
            for functionName: String,
            if completed: Bool
        ) -> String {
            if completed {
                "delete window.\(functionName)"
            } else {
                ""
            }
        }
    }
}
