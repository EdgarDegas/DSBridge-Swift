//
//  File.swift
//  
//
//  Created by iMoe Nya on 2024/3/26.
//

import Foundation

public struct MethodQuery {
    public var rawName: String
    public var type: `Type`
    
    public init(rawName: String, rawType: String) {
        self.rawName = rawName
        self.type = `Type`(rawValue: rawType)
    }
    
    public enum `Type` {
        case asynchronous
        case synchronous
        case either
        
        var isSynchronous: Bool? {
            switch self {
            case .asynchronous:
                return false
            case .synchronous:
                return true
            case .either:
                return nil
            }
        }
        
        public init(rawValue: String) {
            switch rawValue {
            case "asyn":
                self = .asynchronous
            case "syn":
                self = .synchronous
            default:
                self = .either
            }
        }
    }
}
