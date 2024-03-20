//
//  File.swift
//  
//
//  Created by iMoe Nya on 2024/3/22.
//

import Foundation

public final class JSONSerializer: JSONSerializing {
    static var readingOptions: JSONSerialization.ReadingOptions {
        if #available(iOS 15, *) {
            return [.json5Allowed, .fragmentsAllowed]
        } else {
            return .fragmentsAllowed
        }
    }
    
    public init() { }
    
    public func readParamters(
        from text: JSON?
    ) throws -> JSInvocation.Signature {
        guard let text else {
            // calling a method with no parameter nor callback
            return JSInvocation.Signature()
        }
        guard let rawData = text.data(using: .utf8) else {
            throw Error.JSON.ReadingError
                .invalidCallingFromJS(text)
        }
        let decoded = try decode(rawData)
        guard let dict = decoded as? [String: Any] else {
            throw Error.JSON.ReadingError.invalidCallingFromJS(text)
        }
        let parameter: Any? = {
            let raw = dict[Self.parameterKey]
            if raw is NSNull {
                return nil
            } else {
                return raw
            }
        }()
        return JSInvocation.Signature(
            parameter: parameter,
            callback: {
                if let callback = dict[Self.callbackKey] as? String {
                    return callback
                } else {
                    return nil
                }
            }()
        )
    }
    
    private func decode(_ rawData: Data) throws -> Any {
        do {
            return try JSONSerialization.jsonObject(
                with: rawData, options: Self.readingOptions
            )
        } catch {
            throw Error.JSON.ReadingError.underlyingJSONSerialization(error)
        }
    }

    public func serialize(_ object: Any) throws -> JSON {
        let encoded = try encode(object)
        guard let string = String(data: encoded, encoding: .utf8) else {
            throw Error.JSON.WritingError.failedToEncode(object)
        }
        return string
    }
    
    private func encode(_ object: Any) throws -> Data {
        do {
            return try JSONSerialization.data(withJSONObject: object)
        } catch {
            throw Error.JSON.WritingError.underlyingJSONEncoding(error)
        }
    }
}
