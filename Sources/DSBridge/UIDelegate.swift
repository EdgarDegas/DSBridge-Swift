//
//  File.swift
//  
//
//  Created by iMoe Nya on 2024/3/22.
//

import WebKit

open class UIDelegate: NSObject, WKUIDelegate {
    open weak var designatedDelegate: (any WKUIDelegate)?
    
    open var invocationHandler: any JSInvocationHandling
    open var jsonSerializer: any JSONSerializing
    
    open var logger: any ErrorLogging = ErrorLogger.shared
    open var methodResolver:
        any MethodResolving = MethodResolver()
    
    open var evaluationHandler: (String) -> Void
    
    open class var defaultResponse: String {
        #"{"data":"","code":-1}"#
    }
    
    init(
        jsonSerializer: any JSONSerializing,
        invocationHandler: any JSInvocationHandling,
        evaluationHandler: @escaping (String) -> Void
    ) {
        self.jsonSerializer = jsonSerializer
        self.invocationHandler = invocationHandler
        self.evaluationHandler = evaluationHandler
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
            let invocation = JSInvocation(method: method, signature: signature)
            let returned = invocationHandler.handle(
                invocation
            ) { [weak self] parameters, completed in
                self?.performCallback(
                    of: invocation, with: parameters.data, completed: completed
                )
            }
            complete(with: returned, completion: completion)
        } catch {
            logger.logError(error)
            completion(Self.defaultResponse)
        }
    }
    
    open func complete(
        with returned: Response,
        completion: @escaping (String?) -> Void
    ) {
        do {
            let serialized = try jsonSerializer.serialize(
                returned.asDictionary
            )
            completion(serialized)
        } catch {
            logger.logError(error)
        }
    }
    
    open func performCallback(
        of invocation: JSInvocation,
        with data: Any,
        completed: Bool
    ) {
        guard let callback = invocation.signature.callback else {
            let message = "Method marked non-synchronous has no callback."
            assertionFailure(message)
            logger.logMessage(message, at: .error, into: nil)
            return
        }
        do {
            let encoded = try jsonSerializer.serialize(data)
            let deletingScript = writeDeletingScript(for: callback, if: completed)
            evaluationHandler(
                writeScriptCallingBack(
                    callback,
                    encodedData: encoded,
                    deletingScript: deletingScript
                )
            )
        } catch {
            logger.logError(error)
        }
        
        func writeScriptCallingBack(
            _ callback: String,
            encodedData: String,
            deletingScript: String
        ) -> String {
            """
            try {
                \(callback)(JSON.parse(decodeURIComponent(\(encodedData))));
                \(deletingScript);
            } catch(e) {
            
            }
            """
        }
        
        func writeDeletingScript(
            for callback: String,
            if completed: Bool
        ) -> String {
            if completed {
                "delete window.\(callback)"
            } else {
                ""
            }
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
    ) throws -> JSInvocation.Signature {
        try jsonSerializer.readParamters(from: defaultText)
    }
    
    open func getMethod(
        from prompt: String,
        synchronous: Bool
    ) throws -> MethodForJS {
        let raw = String(prompt.dropFirst(Self.prefix.count))
        return try methodResolver.resolveMethodFromRaw(
            raw, synchronous: synchronous
        )
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
