//
//  File.swift
//  
//
//  Created by iMoe Nya on 2024/3/23.
//

import Foundation

public struct IncomingInvocation {
    public var method: Method
    public var signature: Signature
    public var isSynchronous: Bool {
        signature.indicatesSynchronousCall
    }
    
    public struct Signature {
        public var parameter: Any?
        public var callbackFunctionName: String?
        
        public init(parameter: Any? = nil, callbackFunctionName: String? = nil) {
            self.parameter = parameter
            self.callbackFunctionName = callbackFunctionName
        }
        
        public var indicatesSynchronousCall: Bool {
            callbackFunctionName == nil
        }
    }
}
