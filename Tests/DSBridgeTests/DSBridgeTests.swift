import XCTest
@testable import DSBridge
import WebKit

final class DSBridgeTests: XCTestCase {
    @Exposed
    struct Interface {
        func test() {
            Self.testInvoked = true
        }
        func willReturn1() -> Int {
            return 1
        }
        
        func input(_ value: Int) {
            Self.input = value
        }
        
        static var input: Int?
        static var testInvoked = false
        static var blockFuncReturnValue = 800
        func blockFunc(block: (Int) -> Void) {
            block(Self.blockFuncReturnValue)
        }
        
        static var asyncReturningFuncReturnValue = 66
        func asyncReturningFunc() async -> Int {
            return Self.asyncReturningFuncReturnValue
        }
        
        static var asyncFuncCalled = false
        func asyncFunc() async {
            try? await Task.sleep(for: .seconds(0.2))
            Self.asyncFuncCalled = true
        }
    }
    
    var webView: DSBridge.WebView!
    
    func testCallingFromJavaScript() {
        let expectations = [
            XCTestExpectation(),
            XCTestExpectation(),
        ]
        runInJS("bridge.call('test')") { _ in
            XCTAssertTrue(Interface.testInvoked)
            expectations[0].fulfill()
        }
        runInJS("bridge.call('willReturn1')") { returned in
            XCTAssert(returned as! Int == 1)
            expectations[1].fulfill()
        }
        wait(for: expectations)
    }
    
    func testCallingBlockFunc() {
        let expectation = XCTestExpectation()
        runInJS("""
        bridge.call('blockFunc', function(returnValue){
            bridge.call('input', returnValue)
        })
        """) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                XCTAssert(Interface.input == Interface.blockFuncReturnValue)
                expectation.fulfill()
            }
        }
        wait(for: [expectation])
    }
    
    func testCallingAsyncReturningFunc() {
        let expectation = XCTestExpectation()
        runInJS("""
        bridge.call('asyncReturningFunc', function(ret) { bridge.call('input', ret) })
        """) { returned in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                XCTAssert(Interface.input == Interface.asyncReturningFuncReturnValue)
                expectation.fulfill()
            }
        }
        wait(for: [expectation])
    }
    
    func testCallingAsyncFunc() {
        let expectation = XCTestExpectation()
        defer { wait(for: [expectation]) }
        runInJS("""
        bridge.call('asyncFunc', function() { })
        """) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                XCTAssertTrue(Interface.asyncFuncCalled)
                expectation.fulfill()
            }
        }
    }
    
    func testCallingFromNative() {
        let expectations = [XCTestExpectation(), XCTestExpectation()]
        webView.call("addValue", with: [1, 1], thatReturns: Int.self) {
            let returned = try! $0.get()
            XCTAssert(returned == 2)
            expectations[0].fulfill()
        }
        webView.call("append", with: ["1", "2", "3"], thatReturns: String.self) {
            let returned = try! $0.get()
            XCTAssert(returned == "1 2 3")
            expectations[1].fulfill()
        }
        wait(for: expectations)
    }
    
    func testCallingNamespaceFromNative() {
        let expectations = [XCTestExpectation(), XCTestExpectation()]
        webView.call("syncFunctions.returnAsIs", with: [99], thatReturns: Int.self) {
            let returned = try! $0.get()
            XCTAssert(returned == 99)
            expectations[0].fulfill()
        }
        webView.call("asyncFunctions.adding100", with: [7], thatReturns: Int.self) {
            let returned = try! $0.get()
            XCTAssert(returned == 107)
            expectations[1].fulfill()
        }
        wait(for: expectations)
    }
    
    override func setUp() {
        Interface.testInvoked = false
        Interface.input = nil
        Interface.asyncFuncCalled = false
    }
    
    override func invokeTest() {
        let exp = XCTestExpectation()
        webView = DSBridge.WebView()
        injectBridgeScript(into: webView)
        let url = URL(string: "about:blank")!
        webView.load(URLRequest(url: url))
        
        let interface = Interface()
        webView.addInterface(interface, by: nil)
        webView.evaluateJavaScript(
            """
            bridge.register('addValue', function(l, r) {
              return l + r;
            })
            
            bridge.registerAsyn('append', function(arg1, arg2, arg3, respond) {
              respond(arg1 + " " + arg2 + " " + arg3);
            })
            
            bridge.register("syncFunctions",{
              returnAsIs: function(v) {
                return v
              }
            })
            
            bridge.registerAsyn("asyncFunctions",{
              adding100: function(input, respond) {
                respond(input + 100)
              }
            })
            """
        ) { _, _ in
            exp.fulfill()
        }
        wait(for: [exp])
        super.invokeTest()
    }
    
    func runInJS(_ script: String, completion: @escaping (Any?) -> Void) {
        webView.evaluateJavaScript(script) { result, _ in
            completion(result)
        }
    }
    
    func injectBridgeScript(into webView: DSBridge.WebView) {
        webView.configuration.userContentController.addUserScript(
            WKUserScript(
                source: bridgeScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )
    }
    
    var bridgeScript: String {
        """
        var bridge = {
            default:this,// for typescript
            call: function (method, args, cb) {
                var ret = '';
                if (typeof args == 'function') {
                    cb = args;
                    args = {};
                }
                var arg={data:args===undefined?null:args}
                if (typeof cb == 'function') {
                    var cbName = 'dscb' + window.dscb++;
                    window[cbName] = cb;
                    arg['_dscbstub'] = cbName;
                }
                arg = JSON.stringify(arg)

                //if in webview that dsBridge provided, call!
                if(window._dsbridge){
                   ret=  _dsbridge.call(method, arg)
                }else if(window._dswk||navigator.userAgent.indexOf("_dsbridge")!=-1){
                   ret = prompt("_dsbridge=" + method, arg);
                }

               return  JSON.parse(ret||'{}').data
            },
            register: function (name, fun, asyn) {
                var q = asyn ? window._dsaf : window._dsf
                if (!window._dsInit) {
                    window._dsInit = true;
                    //notify native that js apis register successfully on next event loop
                    setTimeout(function () {
                        bridge.call("_dsb.dsinit");
                    }, 0)
                }
                if (typeof fun == "object") {
                    q._obs[name] = fun;
                } else {
                    q[name] = fun
                }
            },
            registerAsyn: function (name, fun) {
                this.register(name, fun, true);
            },
            hasNativeMethod: function (name, type) {
                return this.call("_dsb.hasNativeMethod", {name: name, type:type||"all"});
            },
            disableJavascriptDialogBlock: function (disable) {
                this.call("_dsb.disableJavascriptDialogBlock", {
                    disable: disable !== false
                })
            }
        };

        !function () {
            if (window._dsf) return;
            var ob = {
                _dsf: {
                    _obs: {}
                },
                _dsaf: {
                    _obs: {}
                },
                dscb: 0,
                dsBridge: bridge,
                close: function () {
                    bridge.call("_dsb.closePage")
                },
                _handleMessageFromNative: function (info) {
                    var arg = JSON.parse(info.data);
                    var ret = {
                        id: info.callbackId,
                        complete: true
                    }
                    var f = this._dsf[info.method];
                    var af = this._dsaf[info.method]
                    var callSyn = function (f, ob) {
                        ret.data = f.apply(ob, arg)
                        bridge.call("_dsb.returnValue", ret)
                    }
                    var callAsyn = function (f, ob) {
                        arg.push(function (data, complete) {
                            ret.data = data;
                            ret.complete = complete!==false;
                            bridge.call("_dsb.returnValue", ret)
                        })
                        f.apply(ob, arg)
                    }
                    if (f) {
                        callSyn(f, this._dsf);
                    } else if (af) {
                        callAsyn(af, this._dsaf);
                    } else {
                        //with namespace
                        var name = info.method.split('.');
                        if (name.length<2) return;
                        var method=name.pop();
                        var namespace=name.join('.')
                        var obs = this._dsf._obs;
                        var ob = obs[namespace] || {};
                        var m = ob[method];
                        if (m && typeof m == "function") {
                            callSyn(m, ob);
                            return;
                        }
                        obs = this._dsaf._obs;
                        ob = obs[namespace] || {};
                        m = ob[method];
                        if (m && typeof m == "function") {
                            callAsyn(m, ob);
                            return;
                        }
                    }
                }
            }
            for (var attr in ob) {
                window[attr] = ob[attr]
            }
            bridge.register("_hasJavascriptMethod", function (method, tag) {
                 var name = method.split('.')
                 if(name.length<2) {
                   return !!(_dsf[name]||_dsaf[name])
                 }else{
                   // with namespace
                   var method=name.pop()
                   var namespace=name.join('.')
                   var ob=_dsf._obs[namespace]||_dsaf._obs[namespace]
                   return ob&&!!ob[method]
                 }
            })
        }();

        module.exports = bridge;
        """
    }

}
