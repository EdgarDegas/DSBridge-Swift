//
//  File.swift
//  
//
//  Created by iMoe Nya on 2024/3/23.
//

import Foundation

public struct JSInvocation {
    public var method: MethodForJS
    public var signature: Signature
    public var isSynchronous: Bool {
        signature.indicatesSynchronousCall
    }
    
    public struct Signature {
        public var parameter: Any?
        public var callback: String?
        
        public var indicatesSynchronousCall: Bool {
            callback == nil
        }
    }
}
