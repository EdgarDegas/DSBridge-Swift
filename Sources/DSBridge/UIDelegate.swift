//
//  File.swift
//  
//
//  Created by iMoe Nya on 2024/3/22.
//

import WebKit

open class UIDelegate: NSObject, WKUIDelegate {
    open weak var designatedDelegate: (any WKUIDelegate)?
    open var invocationHandler: (String, String?) -> JSON
    public let prefix: String
    
    init(
        prefix: String,
        invocationHandler: @escaping (String, String?) -> JSON
    ) {
        self.prefix = prefix
        self.invocationHandler = invocationHandler
    }
    
    open func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?, 
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (String?) -> Void
    ) {
        if promptIndicatesJSCall(prompt) {
            let returnValue = invocationHandler(prompt, defaultText)
            completionHandler(returnValue)
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
    
    open func forwardToDesignatedDelegate(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?, initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (String?) -> Void
    ) {
        guard
            let designatedDelegate,
            designatedDelegate.responds(to: Self.injectedSelector)
        else {
            completionHandler(nil)
            return
        }
        designatedDelegate.webView?(
            webView,
            runJavaScriptTextInputPanelWithPrompt: prompt,
            defaultText: defaultText,
            initiatedByFrame: frame,
            completionHandler: completionHandler
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
    
    open func promptIndicatesJSCall(
        _ prompt: String
    ) -> Bool {
        prompt.starts(with: prefix)
    }
}
