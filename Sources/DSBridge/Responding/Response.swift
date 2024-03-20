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
    
    var asDictionary: [String: Any] {
        [
            Self.codeKey: code.rawValue,
            Self.dataKey: data
        ]
    }
    
    static var empty: Self {
        Response(code: .failure, data: "")
    }
    
    public init(code: Code, data: Any?) {
        self.code = code
        self.data = data ?? ""
    }
    
    public enum Code: Int, Encodable {
        case failure = -1
        case success = 0
    }
    
    public static var dataKey: String {
        "data"
    }
    
    public static var codeKey: String {
        "code"
    }
}
