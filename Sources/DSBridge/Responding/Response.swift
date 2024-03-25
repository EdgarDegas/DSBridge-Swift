//
//  File.swift
//
//
//  Created by iMoe Nya on 2024/3/23.
//

import Foundation

public struct Response {
    public var code: Code
    public var data: Any
    
    public var asDictionary: [String: Any] {
        [
            Self.codeKey: code.rawValue,
            Self.dataKey: data
        ]
    }
    
    static var empty: Self {
        Response(code: .unhandled, data: "")
    }
    
    static var emptyJSON: JSON {
        #"{"data":"","code":-1}"#
    }
    
    public init(code: Code, data: Any?) {
        self.code = code
        self.data = data ?? ""
    }
    
    public enum Code: Int, Encodable {
        case unhandled = -1
        case success = 0
    }
    
    public static var dataKey: String {
        "data"
    }
    
    public static var codeKey: String {
        "code"
    }
}

public struct AsyncResponse {
    public var functionName: String
    public var data: Any
    public var completed: Bool
    
    public init(functionName: String, data: Any?, completed: Bool) {
        self.functionName = functionName
        self.data = data ?? ""
        self.completed = completed
    }
}
