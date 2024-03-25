//
//  File.swift
//  
//
//  Created by iMoe Nya on 2024/3/24.
//

import Foundation
import ObjectiveC

/*
 - (id) hasNativeMethod:(id) args
 {
     return [self.webview onMessage:args type: DSB_API_HASNATIVEMETHOD];
 }

 - (id) closePage:(id) args{
     return [self.webview onMessage:args type:DSB_API_CLOSEPAGE];
 }

 - (id) returnValue:(NSDictionary *) args{
     return [self.webview onMessage:args type:DSB_API_RETURNVALUE];
 }

 - (id) dsinit:(id) args{
     return [self.webview onMessage:args type:DSB_API_DSINIT];
 }

 - (id) disableJavaScriptDialogBlock:(id) args{
     return [self.webview onMessage:args type:DSB_API_DISABLESAFETYALERTBOX];
 }
 */

public enum PredefinedJSInvocation {
    case hasMethod(String)
    case close
    case callback(Callback)
    case initialize
}

/// Predefined methods for DSBridge's internal functions.
///
/// Make sure the namespace and function names & signature always match with 
/// the definitions in JavaScript.
@Exposed
public final class PredefinedInterfaceForJS: InterfaceForJS {    
    static var namespace: String {
        "_dsb"
    }
    
    public typealias Handler = (PredefinedJSInvocation) -> Any
    
    private let predefinedInvocationHandler: Handler
    
    public init(predefinedInvocationHandler: @escaping Handler) {
        self.predefinedInvocationHandler = predefinedInvocationHandler
    }
    
    func returnValue(_ info: [String: Any]) {
        guard
            let id = info["id"] as? Int,
            let data = info["data"],
            let completed = info["complete"] as? Bool
        else {
            return
        }
        let callback = Callback(id: id, data: data, completed: completed)
        _ = predefinedInvocationHandler(.callback(callback))
    }
    
    func dsinit() {
        _ = predefinedInvocationHandler(.initialize)
    }
    
    func hasNativeMethod(_ rawMethod: String) -> Bool {
        return predefinedInvocationHandler(
            .hasMethod(rawMethod)
        ) as? Bool ?? false
    }
    
    func closePage() {
        _ = predefinedInvocationHandler(.close)
    }
}
