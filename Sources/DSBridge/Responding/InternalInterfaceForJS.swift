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

@Exposed
public final class InternalInterfaceForJS: InterfaceForJS {
    static var namespace: String {
        "_dsb"
    }
    
    private let callbackHandler: (Callback) -> Void
    
    public init(callbackHandler: @escaping (Callback) -> Void) {
        self.callbackHandler = callbackHandler
    }
    
    public func handleCallback(_ info: [String: Any]) {
        guard
            let id = info["id"] as? Int,
            let data = info["data"],
            let completed = info["complete"] as? Bool
        else {
            return
        }
        let callback = Callback(id: id, data: data, completed: completed)
        callbackHandler(callback)
    }
}
