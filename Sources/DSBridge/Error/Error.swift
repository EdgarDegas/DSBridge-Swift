//
//  File.swift
//  
//
//  Created by iMoe Nya on 2024/3/22.
//

import Foundation

public protocol LoggableError: 
    Swift.Error,
    CustomDebugStringConvertible
{
    static var category: String { get }
    var category: String { get }
}

public extension LoggableError {
    var category: String {
        Self.category
    }
}

public enum Error {
    
}

extension Error {
    public enum JSON { }
}

extension Error.JSON {
    public enum ReadingError: LoggableError {
        public static var category: String {
            "JSON.Reading"
        }
        
        public var debugDescription: String {
            switch self {
            case .invalidCallingFromJS(let string):
                "JS called with invalid parameters: \(string)"
            case .underlyingJSONSerialization(let error):
                "Error from JSONSerialization: \(error)"
            }
        }
        
        case invalidCallingFromJS(String)
        case underlyingJSONSerialization(_ error: Swift.Error)
    }
    
    public enum WritingError: LoggableError {
        public static var category: String {
            "JSON.Writing"
        }
        
        public var debugDescription: String {
            switch self {
            case .failedToEncode(let object):
                "Failed to encode JSON data into UTF-8 text: \(object)"
            case .underlyingJSONEncoding(let error):
                "Error from JSONEncoder: \(error)"
            }
        }
        
        case underlyingJSONEncoding(_ error: Swift.Error)
        case failedToEncode(Any)
    }
}

extension Error {
    public enum NameResolvingError: LoggableError {
        public var debugDescription: String {
            switch self {
            case .invalidFormat(let text):
                return "Calling method in a invalid format \(text)."
            case .namespaceNotFound(let namespace):
                return "No such namespace \(namespace)."
            case .methodNotFound(let method):
                return "Method \(method) not found."
            }
        }
        
        public static var category: String {
            "NameResolving"
        }
        
        case invalidFormat(String)
        case namespaceNotFound(String)
        case methodNotFound(String)
    }
}
