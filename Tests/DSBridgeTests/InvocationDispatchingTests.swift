import XCTest
@testable import DSBridge

@Exposed
final class ExampleInterfaceForJS {
    var f1Invoked = false
    var f2InvokedWithParameter: String?
    static var f3ReturnValue: String {
        "F3"
    }
    static var f4ReturnValue: (String, Bool) {
        ("F4", true)
    }
    static var f5ReturnValue: (Int, Bool) {
        (5, false)
    }
    
    @unexposed
    func reset() {
        f1Invoked = false
        f2InvokedWithParameter = nil
    }
    
    func f1() {
        f1Invoked = true
    }
    
    func f2(parameter: String) {
        f2InvokedWithParameter = parameter
    }
    
    func f3() -> String {
        Self.f3ReturnValue
    }
    
    func f4(completion: (String, Bool) -> Void) {
        completion(Self.f4ReturnValue.0, Self.f4ReturnValue.1)
    }
    
    func f5(flag: Bool, completion: @escaping (Int, Bool) -> Void) {
        completion(Self.f5ReturnValue.0, Self.f5ReturnValue.1)
    }
}

final class InvocationDispatchingTests: XCTestCase {
    lazy var dispatcher: JSInvocationDispatcher = {
        let dispatcher = JSInvocationDispatcher()
        dispatcher.addInterface(
            exampleInterface, by: exampleNamespace
        )
        return dispatcher
    }()
    let exampleNamespace = "exampleNamespace"
    let exampleInterface = ExampleInterfaceForJS()
    
    override func setUp() {
        exampleInterface.reset()
    }
    
    func testInvokingNoParameterNoReturn() throws {
        _ = dispatcher.handle(
            JSInvocation(
                method: MethodForJS(
                    namespace: exampleNamespace, name: "f1"
                ),
                signature: JSInvocation.Signature(parameter: nil, callback: nil)
            )
        ) { response, completed in
            print(response, completed)
        }
        XCTAssertTrue(exampleInterface.f1Invoked)
    }
    
    func testInvokingStringParameterNoReturn() throws {
        let data = "string value"
        _ = dispatcher.handle(
            JSInvocation(
                method: MethodForJS(
                    namespace: exampleNamespace, name: "f2"
                ),
                signature: JSInvocation.Signature(parameter: "string value", callback: nil)
            ),
            callback: nil
        )
        XCTAssert(exampleInterface.f2InvokedWithParameter == data)
    }
    
    func testInvokingNonParameterReturn() throws {
        let returned = dispatcher.handle(
            JSInvocation(
                method: MethodForJS(
                    namespace: exampleNamespace, name: "f3"
                ),
                signature: JSInvocation.Signature(parameter: "string value", callback: nil)
            ),
            callback: nil
        )
        XCTAssert(returned.data as! String == ExampleInterfaceForJS.f3ReturnValue)
    }
    
    func testInvokingCompletion() throws {
        _ = dispatcher.handle(
            JSInvocation(
                method: MethodForJS(
                    namespace: exampleNamespace, name: "f4"
                ),
                signature: JSInvocation.Signature(parameter: "string value", callback: nil)
            )
        ) { value, completed in
            XCTAssert((value.data as! String, completed) == ExampleInterfaceForJS.f4ReturnValue)
        }
    }
    
    func testInvokingParameterCompletion() throws {
        _ = dispatcher.handle(
            JSInvocation(
                method: MethodForJS(
                    namespace: exampleNamespace, name: "f5"
                ),
                signature: JSInvocation.Signature(parameter: "string value", callback: nil)
            )
        ) { value, completed in
            XCTAssert((value.data as! Int, completed) == ExampleInterfaceForJS.f5ReturnValue)
        }
    }
}
