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

public enum PredefinedInvocation {
    case hasMethod(MethodQuery)
    case close
    case handleResponseFromJS(FromJS.Response)
    case initialize
}

/// Predefined methods for DSBridge's internal functions.
///
/// Make sure the namespace and function names & signature always match with
/// the definitions in JavaScript.
//@Exposed
public final class PredefinedInterface {
    static var namespace: String {
        "_dsb"
    }
    
    public var logger: any ErrorLogging = sharedLogger
    
    public typealias Handler = (PredefinedInvocation) -> Any
    
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
            logger.logMessage("_dsb.returnValue called with wrong parameters.", at: .error)
            return
        }
        let response = FromJS.Response(id: id, data: data, completed: completed)
        _ = predefinedInvocationHandler(.handleResponseFromJS(response))
    }
    
    func dsinit() {
        _ = predefinedInvocationHandler(.initialize)
    }
    
    func hasNativeMethod(_ info: [String: String]) -> Bool {
        guard
            let rawName = info["name"],
            let rawType = info["type"]
        else {
            logger.logMessage("hasNativeMethod called with wrong parameters.", at: .error)
            return false
        }
        return predefinedInvocationHandler(
            .hasMethod(MethodQuery(rawName: rawName, rawType: rawType))
        ) as? Bool ?? false
    }
    
    func closePage() {
        _ = predefinedInvocationHandler(.close)
    }
}

extension PredefinedInterface: ExposedInterface {
    var synchronousFunctions: [String: Any] {
        [
            "returnValue": returnValue,
            "dsinit": dsinit,
            "hasNativeMethod": hasNativeMethod,
            "closePage": closePage
        ]
    }
    
    var asynchronousFunctions: [String: Any] {
        [
            :
        ]
    }
    
    public func handle(
        calling methodName: String,
        with parameter: Any?
    ) -> Any? {
        let function = synchronousFunctions[methodName]
        switch methodName {
        case "returnValue":
            guard
                let parameter = parameter as? [String: Any]
            else {
                return nil
            }
            returnValue(parameter)
        case "dsinit":
            dsinit()
        case "hasNativeMethod":
            guard
                let parameter = parameter as? [String: String]
            else {
                return nil
            }
            return hasNativeMethod(parameter)
        case "closePage":
            closePage()
        default:
            break
        }
        return nil
    }
    
    public func handle(
        calling methodName: String,
        with parameter: Any?,
        completion: @escaping (Any?, Bool) -> Void
    ) {
        
    }
    
    public func hasMethod(
        named name: String,
        isSynchronous: Bool?
    ) -> Bool {
        if isSynchronous == true {
            synchronousFunctions.keys.contains(name)
        } else if isSynchronous == false {
            asynchronousFunctions.keys.contains(name)
        } else {
            synchronousFunctions.keys.contains(name) ||
            asynchronousFunctions.keys.contains(name)
        }
    }
}
