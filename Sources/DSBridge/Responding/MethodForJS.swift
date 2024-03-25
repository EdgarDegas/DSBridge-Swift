//
//  File.swift
//  
//
//  Created by iMoe Nya on 2024/3/23.
//

import Foundation

public struct MethodForJS: Equatable {
    public var namespace: String
    public var name: String
    
    public var fullname: String {
        "\(namespace).\(name)"
    }
}


public protocol MethodResolving {
    func resolveMethodFromRaw(
        _ raw: String
    ) throws -> MethodForJS
}

public struct MethodResolver: MethodResolving {
    public init() { }
    
    public func resolveMethodFromRaw(
        _ raw: String
    ) throws -> MethodForJS {
        let substrings = raw.split(
            separator: ".",
            omittingEmptySubsequences: false
        )
        guard
            substrings.count == 1 ||
            substrings.count == 2
        else {
            throw Error.NameResolvingError.invalidFormat(raw)
        }
        let strings = try {
            var strings = [String]()
            for substring in substrings {
                guard !substring.isEmpty else {
                    throw Error.NameResolvingError.invalidFormat(raw)
                }
                strings.append(String(substring))
            }
            return strings
        }()
        if strings.count == 1 {
            return MethodForJS(
                namespace: "",
                name: strings[0]
            )
        } else {
            return MethodForJS(
                namespace: strings[0],
                name: strings[1]
            )
        }
    }

}
