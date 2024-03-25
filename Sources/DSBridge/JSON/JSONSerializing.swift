//
//  File.swift
//  
//
//  Created by iMoe Nya on 2024/3/22.
//

import Foundation

public protocol JSONSerializing {
    func readParamters(
        from text: JSON?
    ) throws -> IncomingInvocation.Signature
    
    func serialize(
        _ object: Any
    ) throws -> JSON
}

public extension JSONSerializing {
    static var callbackKey: String {
        "_dscbstub"
    }
    
    static var parameterKey: String {
        "data"
    }
}
