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
    
    open lazy var keystone: any KeystoneProtocol = Keystone(
        javaScriptEvaluationHandler: { [weak self] in
            self?.evaluateJavaScript($0)
        },
        dismissalHandler: { [weak self] in
            self?.dismissalHandler?()
        }
    )
    
    open var dismissalHandler: (() -> Void)?
    
    open lazy var innerUIDelegate = UIDelegate(
        prefix: keystone.invocationPrefix
    ) { [weak self] prompt, defaultText in
        self?.keystone.handleRawInvocation(
            prompt: prompt, defaultText: defaultText
        )
            ?? Response.emptyJSON
    }
    
    public override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        setEnvironmentVariable()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setEnvironmentVariable()
    }
    
    func setEnvironmentVariable() {
        super.uiDelegate = innerUIDelegate
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: "window._dswk=true;",
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )
    }
    
    open func call(
        _ methodName: String,
        with parameter: [Any]
    ) {
        keystone.call(methodName, with: parameter, completion: nil)
    }
    
    /// Call JavaScript handler.
    open func call<T>(
        _ methodName: String,
        with parameter: [Any],
        completion: @escaping (Result<T, any Swift.Error>) -> Void
    ) {
        keystone.call(methodName, with: parameter) {
            guard let result = $0 as? T else {
                completion(.failure(Error.CallingJS.returnTypeMismatch($0)))
                return
            }
            completion(.success(result))
        }
    }
    
    ///Add a JavaScript Object to dsBridge with namespace.
    ///- Parameters:
    ///  - object: Object which implemented the JavaScript interfaces.
    ///  - namespace: If empty, the object have no namespace.
    open func addInterface(_ interface: ExposedInterface, by namespace: String?) {
        keystone.addInterface(interface, by: namespace ?? "")
    }
    
    /// Remove the JavaScript Object with the supplied namespace.
    open func removeInterface(by namespace: String?) {
        keystone.removeInterface(by: namespace ?? "")
    }
    
    /// Test whether the handler exist in JavaScript.
    open func hasJavaScriptMethod(
        named name: String,
        completion: @escaping (Bool) -> Void
    ) {
        keystone.hasJavaScriptMethod(named: name, completion: completion)
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
    
}
