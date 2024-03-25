//
//  File.swift
//  
//
//  Created by iMoe Nya on 2024/3/22.
//

import WebKit

open class UIDelegate: NSObject, WKUIDelegate {
    open weak var designatedDelegate: (any WKUIDelegate)?
    open var jsonSerializer: any JSONSerializing
    open var logger: any ErrorLogging = ErrorLogger.shared
    open var methodResolver: any MethodResolving
    open var invocationHandler: (IncomingInvocation) -> JSON
    
    init(
        jsonSerializer: any JSONSerializing,
        methodResolver: any MethodResolving,
        invocationHandler: @escaping (IncomingInvocation) -> JSON
    ) {
        self.jsonSerializer = jsonSerializer
        self.invocationHandler = invocationHandler
        self.methodResolver = methodResolver
    }
    
    open func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?, 
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (String?) -> Void
    ) {
        if Self.promptIndicatesJSCall(prompt) {
            handleJSCall(
                prompt: prompt,
                defaultText: defaultText,
                completion: completionHandler
            )
        } else {
            forwardToDesignatedDelegate(
                webView,
                runJavaScriptTextInputPanelWithPrompt: prompt,
                defaultText: defaultText,
                initiatedByFrame: frame,
                completionHandler: completionHandler
            )
        }
    }
    
    open func handleJSCall(
        prompt: String,
        defaultText: String?,
        completion: @escaping (String?) -> Void
    ) {
        do {
            let signature = try getSignature(from: defaultText)
            let method = try getMethod(
                from: prompt,
                synchronous: signature.indicatesSynchronousCall
            )
            let invocation = IncomingInvocation(method: method, signature: signature)
            let response = invocationHandler(invocation)
            completion(response)
        } catch {
            logger.logError(error)
            completion(Response.emptyJSON)
        }
    }
    
    open func forwardToDesignatedDelegate(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?, initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (String?) -> Void
    ) {
        guard let designatedDelegate else { return }
        designatedDelegate.webView?(
            webView,
            runJavaScriptTextInputPanelWithPrompt: prompt,
            defaultText: defaultText,
            initiatedByFrame: frame,
            completionHandler: completionHandler
        )
    }
    
    open func getSignature(
        from defaultText: String?
    ) throws -> IncomingInvocation.Signature {
        try jsonSerializer.readParamters(from: defaultText)
    }
    
    open func getMethod(
        from prompt: String,
        synchronous: Bool
    ) throws -> Method {
        let raw = String(prompt.dropFirst(Self.prefix.count))
        return try methodResolver.resolveMethodFromRaw(raw)
    }
    
    open override func responds(to aSelector: Selector!) -> Bool {
        if aSelector == Self.injectedSelector {
            return true
        } else {
            return designatedDelegate?.responds(to: aSelector) ?? false
        }
    }
    
    open override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if designatedDelegate?.responds(to: aSelector) == true {
            return designatedDelegate
        } else {
            return nil
        }
    }
    
    open class var injectedSelector: Selector {
        #selector(
            webView(
                _:
                runJavaScriptTextInputPanelWithPrompt:
                defaultText:
                initiatedByFrame:
                completionHandler:
            )
        )
    }
    
    open class var prefix: String {
        "_dsbridge="
    }
    
    open class func promptIndicatesJSCall(
        _ prompt: String
    ) -> Bool {
        prompt.starts(with: Self.prefix)
    }
}
