//
//  File.swift
//  
//
//  Created by iMoe Nya on 2024/3/22.
//

import Foundation

public final class JSONSerializer: JSONSerializing {
    static var readingOptions: JSONSerialization.ReadingOptions {
        if #available(iOS 15, macOS 12.0, *) {
            return [.json5Allowed, .fragmentsAllowed]
        } else {
            return .fragmentsAllowed
        }
    }
    
    public init() { }
    
    public func readParamters(
        from text: JSON?
    ) throws -> IncomingInvocation.Signature {
        guard let text else {
            // A call with no parameter nor callback
            return IncomingInvocation.Signature()
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
        return IncomingInvocation.Signature(
            parameter: parameter,
            callbackFunctionName: {
                if let functionName = dict[Self.callbackKey] as? String {
                    return functionName
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
        if isNotCollection(object) {
            return try encodeNonCollectionObject(object)
        }
        guard JSONSerialization.isValidJSONObject(object) else {
            throw Error.JSON.WritingError.invalidJSONObject(object)
        }
        let encoded = try encode(object)
        guard let string = String(data: encoded, encoding: .utf8) else {
            throw Error.JSON.WritingError.failedToEncode(object)
        }
        return string
    }
    
    private func isNotCollection(_ object: Any) -> Bool {
        !(object is NSArray || object is NSDictionary)
    }
    
    private func encodeNonCollectionObject(_ object: Any) throws -> JSON {
        switch object {
        case let object as Bool:
            return "\(object)"
        case let object as String:
            return "\"\(object)\""
        case let object as NSNumber:
            return "\(object)"
        default:
            throw Error.JSON.WritingError.invalidJSONObject(object)
        }
    }
    
    private func encode(_ object: Any) throws -> Data {
        do {
            return try JSONSerialization.data(
                withJSONObject: object,
                options: .fragmentsAllowed
            )
        } catch {
            throw Error.JSON.WritingError.underlyingJSONEncoding(error)
        }
    }
}
