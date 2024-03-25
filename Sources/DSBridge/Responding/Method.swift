//
//  File.swift
//  
//
//  Created by iMoe Nya on 2024/3/23.
//

import Foundation

public struct Method: Equatable, CustomStringConvertible {
    public var namespace: String
    public var name: String
    
    public var description: String {
        if namespace.isEmpty {
            return name
        } else {
            return "\(namespace).\(name)"
        }
    }
}

public protocol MethodResolving {
    func resolveMethodFromRaw(
        _ raw: String
    ) throws -> Method
}

public struct MethodResolver: MethodResolving {
    public init() { }
    
    public func resolveMethodFromRaw(
        _ raw: String
    ) throws -> Method {
        guard let dotIndex = raw.lastIndex(of: ".") else {
            if raw.isEmpty {
                throw Error.NameResolvingError.invalidFormat(raw)
            } else {
                return Method(namespace: "", name: raw)
            }
        }
        guard 
            dotIndex > raw.startIndex,
            dotIndex < raw.index(before: raw.endIndex)
        else {
            throw Error.NameResolvingError.invalidFormat(raw)
        }
        let namespace = String(raw[..<dotIndex])
        let name = String(raw[dotIndex...].dropFirst())
        return Method(namespace: namespace, name: name)
    }
}
