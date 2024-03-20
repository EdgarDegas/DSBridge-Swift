import XCTest
@testable import DSBridge

@Exposed
final class ExampleExposedInterface {
    var f1Invoked = false
    var f2InvokedWithParameter: String?
    static var f3ReturnValue: String {
        "F3"
    }
    
    static var f4ReturnValue: (String, Bool) {
        ("F4", true)
    }
    
    var f5PassedInParameter: Bool!
    static var f5ReturnValue: (Int, Bool) {
        (5, false)
    }
    
    @unexposed
    func reset() {
        f1Invoked = false
        f2InvokedWithParameter = nil
        f5PassedInParameter = nil
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
        f5PassedInParameter = flag
        completion(Self.f5ReturnValue.0, Self.f5ReturnValue.1)
    }
}

final class InvocationDispatchingTests: XCTestCase {
    lazy var dispatcher: InvocationDispatcher = {
        let dispatcher = InvocationDispatcher { [unowned self] asyncResponse in
            self.asyncResponse = asyncResponse
        }
        dispatcher.addInterface(
            exampleInterface, by: exampleNamespace
        )
        return dispatcher
    }()
    var asyncResponse: AsyncResponse!
    let exampleNamespace = "exampleNamespace"
    let exampleInterface = ExampleExposedInterface()
    
    override func setUp() {
        exampleInterface.reset()
        asyncResponse = nil
    }
    
    func testInvokingNoParameterNoReturn() throws {
        let returned = dispatcher.dispatch(
            IncomingInvocation(
                method: Method(
                    namespace: exampleNamespace, name: "f1"
                ),
                signature: IncomingInvocation.Signature(parameter: nil, callbackFunctionName: nil)
            )
        )
        XCTAssert(returned.code == .success)
        XCTAssert(returned.data as! String == "")
        XCTAssertTrue(exampleInterface.f1Invoked)
    }
    
    func testInvokingStringParameterNoReturn() throws {
        let data = "string value"
        let returned = dispatcher.dispatch(
            IncomingInvocation(
                method: Method(
                    namespace: exampleNamespace, name: "f2"
                ),
                signature: IncomingInvocation.Signature(parameter: data, callbackFunctionName: nil)
            )
        )
        XCTAssert(returned.code == .success)
        XCTAssert(returned.data as! String == "")
        XCTAssert(exampleInterface.f2InvokedWithParameter == data)
    }
    
    func testInvokingNonParameterReturn() throws {
        let returned = dispatcher.dispatch(
            IncomingInvocation(
                method: Method(
                    namespace: exampleNamespace, name: "f3"
                ),
                signature: IncomingInvocation.Signature(parameter: "string value", callbackFunctionName: nil)
            )
        )
        XCTAssert(returned.data as! String == ExampleExposedInterface.f3ReturnValue)
    }
    
    func testInvokingCompletion() throws {
        let returned = dispatcher.dispatch(
            IncomingInvocation(
                method: Method(
                    namespace: exampleNamespace, name: "f4"
                ),
                signature: IncomingInvocation.Signature(
                    parameter: "string value",
                    callbackFunctionName: "funcInJS"
                )
            )
        )
        XCTAssert(returned.code == Response.empty.code)
        XCTAssert(returned.data as! String == "")
        XCTAssert(asyncResponse.functionName == "funcInJS")
        XCTAssert(asyncResponse.data as! String == ExampleExposedInterface.f4ReturnValue.0)
        XCTAssert(asyncResponse.completed == ExampleExposedInterface.f4ReturnValue.1)
    }
    
    func testInvokingParameterCompletion() throws {
        let returned = dispatcher.dispatch(
            IncomingInvocation(
                method: Method(
                    namespace: exampleNamespace, name: "f5"
                ),
                signature: IncomingInvocation.Signature(
                    parameter: true,
                    callbackFunctionName: "funcInJSF5"
                )
            )
        )
        XCTAssert(exampleInterface.f5PassedInParameter == true)
        XCTAssert(returned.code == Response.empty.code)
        XCTAssert(returned.data as! String == "")
        XCTAssertEqual(asyncResponse.functionName, "funcInJSF5")
        XCTAssert(
            (asyncResponse.data as! Int, asyncResponse.completed)
                == ExampleExposedInterface.f5ReturnValue
        )
    }
}
