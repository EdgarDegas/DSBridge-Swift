import XCTest
@testable import DSBridge

@Exposed
final class ExampleInterfaceForJS: InterfaceForJS {
    var f1Invoked = false
    var f2InvokedWithParameter: String?
    
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
        "F3"
    }
    
    func f4(completion: (String, Bool) -> Void) {
        
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
}
