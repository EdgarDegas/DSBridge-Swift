//
//  File.swift
//  
//
//  Created by iMoe Nya on 2024/3/23.
//

import XCTest
@testable import DSBridge

final class InvocationResolvingTests: XCTestCase {
    let methodResolver = MethodResolver()
    let jsonSerializer = JSONSerializer()
    
    func testGettingMethod() throws {
        XCTAssert(
            try methodResolver.resolveMethodFromRaw("a.b", synchronous: true) ==
                MethodForJS(isSynchronous: true, namespace: "a", name: "b")
        )
        
        XCTAssert(
            try methodResolver.resolveMethodFromRaw("a.b", synchronous: false) ==
                MethodForJS(isSynchronous: false, namespace: "a", name: "b")
        )
    }
    
    func testGettingSignature() throws {
        XCTAssert({
            let jsonString = """
            {
                "data": 1.1,
                "_dscbstub": "callback"
            }
            """
            let resolved = try! jsonSerializer.readParamters(from: jsonString)
            return resolved.callback == "callback" && (resolved.parameter as! Double) == 1.1
        }())
        
        XCTAssert({
            let jsonString = """
            {
                "data": 1
            }
            """
            let resolved = try! jsonSerializer.readParamters(from: jsonString)
            return (resolved.parameter as! Int) == 1
        }())
        
        XCTAssert({
            let jsonString = """
            {
                "data": "s"
            }
            """
            let resolved = try! jsonSerializer.readParamters(from: jsonString)
            return (resolved.parameter as! String) == "s"
        }())
        
        // JSON5 supported
        XCTAssert({
            let jsonString = """
            {
                data: ["s", 1, ["r"]]
            }
            """
            let resolved = try! jsonSerializer.readParamters(from: jsonString).parameter as! [Any]
            return
                resolved[0] as! String == "s" &&
                resolved[1] as! Int == 1 &&
                resolved[2] as! [String] == ["r"]
        }())
        
        XCTAssert({
            let jsonString = """
            {
                data: { key: "value" }
            }
            """
            let resolved = try! jsonSerializer.readParamters(from: jsonString).parameter as! [String: String]
            return resolved["key"] == "value"
        }())
        
        XCTAssert({
            let jsonString = """
            {
                data: true
            }
            """
            let resolved = try! jsonSerializer.readParamters(from: jsonString)
            return (resolved.parameter as! Bool) == true
        }())
        
        XCTAssert({
            let jsonString = """
            {
                data: false
            }
            """
            let resolved = try! jsonSerializer.readParamters(from: jsonString)
            return (resolved.parameter as! Bool) == false
        }())

        XCTAssert({
            let jsonString = """
            {
                "data": null
            }
            """
            let resolved = try! jsonSerializer.readParamters(from: jsonString)
            return resolved.parameter == nil
        }())
    }
    
    func testGettingSignatureFromInvalidText() throws {
        XCTAssertThrowsError(
            try jsonSerializer.readParamters(from: "")
        ) {
            XCTAssert($0 is DSBridge.Error.JSON.ReadingError)
        }
        
        XCTAssertThrowsError(
            try jsonSerializer.readParamters(from: "[\"array\"]")
        ) {
            XCTAssert($0 is DSBridge.Error.JSON.ReadingError)
        }
        
        XCTAssertThrowsError(
            try jsonSerializer.readParamters(from: "\"singleValue\"")
        ) {
            XCTAssert($0 is DSBridge.Error.JSON.ReadingError)
        }
        
        XCTAssertThrowsError(
            try jsonSerializer.readParamters(from: "1")
        ) {
            XCTAssert($0 is DSBridge.Error.JSON.ReadingError)
        }
    }
    
    func testGettingMethodFromInvalidPrompt() throws {
        XCTAssertThrowsError(
            try methodResolver.resolveMethodFromRaw("", synchronous: true)
        ) {
            XCTAssert($0 is DSBridge.Error.NameResolvingError)
        }
        XCTAssertThrowsError(
            try methodResolver.resolveMethodFromRaw(".b", synchronous: true)
        ) {
            XCTAssert($0 is DSBridge.Error.NameResolvingError)
        }
        XCTAssertThrowsError(
            try methodResolver.resolveMethodFromRaw("a.", synchronous: true)
        ) {
            XCTAssert($0 is DSBridge.Error.NameResolvingError)
        }
        XCTAssertThrowsError(
            try methodResolver.resolveMethodFromRaw("a.b.c", synchronous: true)
        ) {
            XCTAssert($0 is DSBridge.Error.NameResolvingError)
        }
        XCTAssertThrowsError(
            try methodResolver.resolveMethodFromRaw("", synchronous: false)
        ) {
            XCTAssert($0 is DSBridge.Error.NameResolvingError)
        }
        XCTAssertThrowsError(
            try methodResolver.resolveMethodFromRaw(".b", synchronous: false)
        ) {
            XCTAssert($0 is DSBridge.Error.NameResolvingError)
        }
        XCTAssertThrowsError(
            try methodResolver.resolveMethodFromRaw("a.", synchronous: false)
        ) {
            XCTAssert($0 is DSBridge.Error.NameResolvingError)
        }
        XCTAssertThrowsError(
            try methodResolver.resolveMethodFromRaw("a.b.c", synchronous: false)
        ) {
            XCTAssert($0 is DSBridge.Error.NameResolvingError)
        }
    }
}
