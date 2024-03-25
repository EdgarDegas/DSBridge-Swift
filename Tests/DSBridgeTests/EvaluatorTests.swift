//
//  File.swift
//  
//
//  Created by iMoe Nya on 2024/3/26.
//

import XCTest
@testable import DSBridge

final class EvaluatorTests: XCTestCase {
    var evaluator: JavaScriptEvaluator!
    
    var evaluated = ""
    var f1CompletedWith = ""
    var f2CompletionCalled = 0
    
    override func setUp() {
        evaluator = JavaScriptEvaluator { [unowned self] script in
            self.evaluated.append(script)
        }
        evaluated = ""
        f1CompletedWith = ""
        f2CompletionCalled = 0
    }
    
    func testBeforeInitialization() {
        let script = "V"
        evaluator.evaluate(script)
        XCTAssertTrue(evaluated.isEmpty)
    }
    
    func testInitialization() {
        let script = "S"
        evaluator.evaluate(script)
        XCTAssertTrue(evaluated.isEmpty)
        evaluator.initialize()
        let expectation = XCTestExpectation(description: "expect evaluation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            XCTAssert(evaluated == script)
            expectation.fulfill()
        }
        wait(for: [expectation])
    }
    
    func testEnqueueBeforeInitialization() {
        let scripts = ["D", "A", "B"]
        scripts.forEach {
            evaluator.evaluate($0)
        }
        XCTAssertTrue(evaluated.isEmpty)
        let expectation1 = XCTestExpectation()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            XCTAssert(evaluated.isEmpty)
            expectation1.fulfill()
        }
        wait(for: [expectation1])
        evaluator.initialize()
        let expectation2 = XCTestExpectation()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            XCTAssert(evaluated == scripts.joined(separator: "\n"))
            expectation2.fulfill()
        }
        wait(for: [expectation2])
    }
    
    func testEnqueueAfterInitialization() {
        let scripts = ["M", "N", "Q"]
        evaluator.initialize()
        scripts.forEach {
            evaluator.evaluate($0)
        }
        XCTAssertTrue(evaluated.isEmpty)
        let expectation = XCTestExpectation(description: "expect evaluation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            XCTAssert(evaluated == scripts.joined(separator: "\n"))
            expectation.fulfill()
        }
        wait(for: [expectation])
    }
    
    func testCalling() {
        let script = Self.scriptFor(calling: "F1", with: "Single String", id: 0)
        evaluator.initialize()
        evaluator.call("F1", with: "Single String") { [self] in
            self.f1CompletedWith = $0 as! String
        }
        let expectation = XCTestExpectation()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            XCTAssert(evaluated == script)
            XCTAssert(self.f1CompletedWith == "RET")
            expectation.fulfill()
        }
        evaluator.handleResponse(FromJS.Response(id: 0, data: "RET", completed: true))
        XCTAssert(f1CompletedWith.isEmpty)
        wait(for: [expectation])
    }
    
    func testCallingMultipleTimes() {
        let scripts = [
            Self.scriptFor(calling: "Z", with: 1, id: 0),
            Self.scriptFor(calling: "X", with: true, id: 1),
            Self.scriptFor(calling: "C", with: 2.2, id: 2)
        ]
        evaluator.initialize()
        evaluator.call("Z", with: "1") { [self] in
            self.f1CompletedWith = $0 as! String
        }
        evaluator.call("X", with: "true") { [self] in
            self.f1CompletedWith = $0 as! String
        }
        evaluator.call("C", with: "2.2") { [self] in
            self.f1CompletedWith = $0 as! String
        }
        let expectation = XCTestExpectation()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            XCTAssert(evaluated == scripts.joined(separator: "\n"))
            expectation.fulfill()
        }
        wait(for: [expectation])
    }
    
    func testReactivatingTimer() {
        evaluator.initialize()
        let scripts1 = ["Q", "W", "E"]
        let scripts2 = ["FF", "WW", "CC"]
        scripts1.forEach {
            evaluator.evaluate($0)
        }
        let exp1 = XCTestExpectation()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            XCTAssert(evaluated == scripts1.joined(separator: "\n"))
            exp1.fulfill()
        }
        wait(for: [exp1])
        let exp2 = XCTestExpectation()
        scripts2.forEach {
            evaluator.evaluate($0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            XCTAssert(evaluated == scripts1.joined(separator: "\n") + scripts2.joined(separator: "\n"))
            exp2.fulfill()
        }
        wait(for: [exp2])
    }
    
    func testOneTimeCompletion() {
        evaluator.initialize()
        evaluator.call("F2", with: "MED") { [self] _ in
            self.f2CompletionCalled += 1
        }
        let expectation = XCTestExpectation()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            XCTAssert(f2CompletionCalled == 1)
            expectation.fulfill()
        }
        evaluator.handleResponse(FromJS.Response(id: 0, data: "", completed: true))
        evaluator.handleResponse(FromJS.Response(id: 0, data: "", completed: true))
        XCTAssert(f2CompletionCalled == 0)
        wait(for: [expectation])
    }
    
    func testMultiTimeCompletion() {
        evaluator.initialize()
        evaluator.call("F2", with: "MED") { [self] _ in
            self.f2CompletionCalled += 1
        }
        let expectation = XCTestExpectation()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            XCTAssert(f2CompletionCalled == 3)
            expectation.fulfill()
        }
        evaluator.handleResponse(FromJS.Response(id: 0, data: "", completed: false))
        evaluator.handleResponse(FromJS.Response(id: 0, data: "", completed: false))
        evaluator.handleResponse(FromJS.Response(id: 0, data: "", completed: true))
        evaluator.handleResponse(FromJS.Response(id: 0, data: "", completed: false))
        XCTAssert(f2CompletionCalled == 0)
        wait(for: [expectation])
    }
    
    static func scriptFor(
        calling functionName: String,
        with parameter: Any,
        id: Int
    ) -> String {
        let message = """
        {
            "method": "\(functionName)",
            "callbackId": \(id),
            "data": \(parameter)
        }
        """
        return "window._handleMessageFromNative(\(message))"
    }
}
