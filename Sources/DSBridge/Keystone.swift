//
//  File.swift
//  
//
//  Created by iMoe Nya on 2024/3/26.
//

import Foundation

public protocol KeystoneProtocol {
    var invocationPrefix: String { get }
    func handleRawInvocation(prompt: String, defaultText: String?) -> JSON?
    func call(
        _ methodName: String,
        with parameter: Any?,
        completion: ((Result<Any, any Swift.Error>) -> Void)?
    )
    func addInterface(_ interface: ExposedInterface, by namespace: String)
    func removeInterface(by namespace: String)
    func hasJavaScriptMethod(named name: String, completion: @escaping (Bool) -> Void)
}

open class Keystone: KeystoneProtocol {
    open var jsonSerializer: any JSONSerializing = JSONSerializer()
    open var methodResolver: any MethodResolving = MethodResolver()
    open var logger: ErrorLogging = sharedLogger
    
    open lazy var invocationDispatcher: any InvocationDispatching
        = InvocationDispatcher
    { [weak self] asyncResponse in
        self?.deliverAsyncResponse(asyncResponse)
    }
    
    open lazy var javaScriptEvaluator: any JavaScriptEvaluating =
        JavaScriptEvaluator
    { [weak self] script in
        self?.evaluateJavaScript(script)
    }
    
    private lazy var predefinedExposedInterface =
        PredefinedInterface
    { [weak self] invocation in
        self?.handlePredefinedInvocation(invocation) ?? Void()
    }
    
    private let evaluateJavaScript: (String) -> Void
    private let dismissalHandler: () -> Void
    
    public init(
        javaScriptEvaluationHandler: @escaping (String) -> Void,
        dismissalHandler: @escaping () -> Void
    ) {
        self.evaluateJavaScript = javaScriptEvaluationHandler
        self.dismissalHandler = dismissalHandler
        invocationDispatcher.addInterface(
            predefinedExposedInterface,
            by: PredefinedInterface.namespace
        )
    }
    
    open func call(
        _ methodName: String,
        with parameter: Any?,
        completion: ((Result<Any, any Swift.Error>) -> Void)?
    ) {
        do {
            let encoded = try encodeParameter(parameter)
            javaScriptEvaluator.call(methodName, with: encoded) {
                completion?(.success($0))
            }
        } catch {
            logger.logError(error)
            completion?(.failure(error))
        }
        
        func encodeParameter(_ parameter: Any?) throws -> JSON {
            do {
                return if let parameter {
                    try jsonSerializer.serialize(parameter)
                } else {
                    ""
                }
            } catch {
                throw Error.CallingJS.underlying(error)
            }
        }
    }
    
    open func addInterface(_ interface: ExposedInterface, by namespace: String) {
        invocationDispatcher.addInterface(interface, by: namespace)
    }
    
    open func removeInterface(by namespace: String) {
        invocationDispatcher.removeInterface(by: namespace)
    }
    
    open func hasJavaScriptMethod(named name: String, completion: @escaping (Bool) -> Void) {
        call("_hasJavascriptMethod", with: name) {
            let has = try? $0.get() as? Bool
            completion(has ?? false)
        }
    }
    
    func handleIncomingInvocation(
        _ invocation: IncomingInvocation
    ) -> JSON? {
        let response = invocationDispatcher.dispatch(invocation)
        do {
            let json = try jsonSerializer.serialize(response.asDictionary)
            return json
        } catch {
            logger.logError(error)
            return nil
        }
    }
    
    func handlePredefinedInvocation(
        _ predefinedInvocation: PredefinedInvocation
    ) -> Any {
        switch predefinedInvocation {
        case .handleResponseFromJS(let callback):
            javaScriptEvaluator.handleResponse(callback)
        case .initialize:
            javaScriptEvaluator.initialize()
        case .close:
            dismissalHandler()
        case .hasMethod(let methodQuery):
            do {
                let method = try methodResolver.resolveMethodFromRaw(
                    methodQuery.rawName
                )
                let result = invocationDispatcher.hasMethod(
                    method, isSynchronous: methodQuery.type.isSynchronous
                )
                return result
            } catch {
                logger.logMessage(
                    "Failed to resolve method from text: \(methodQuery).",
                    at: .debug
                )
                return false
            }
        }
        return Void()
    }
    
    open func deliverAsyncResponse(
        _ response: AsyncResponse
    ) {
        let functionName = response.functionName
        let data = response.data
        let completed = response.completed
        do {
            var encoded = "";
            if let stringData = data as? String {
                //如果是字符串 不执行json序列化
                encoded = stringData;
            }else{
                encoded = try jsonSerializer.serialize(data)
            }
             
            encoded = clStringConvert(encoded)
            let deletingScript = writeDeletingScript(
                for: functionName, if: completed
            )
            javaScriptEvaluator.evaluate(
                writeScriptCallingBack(
                    to: functionName,
                    encodedData: encoded,
                    deletingScript: deletingScript
                )
            )
        } catch {
            logger.logError(error)
        }
        
        func writeScriptCallingBack(
            to functionName: String,
            encodedData: String,
            deletingScript: String
        ) -> String {
            """
            try {
                let encodedData = "\(encodedData)";
                let json =JSON.parse(decodeURIComponent(encodedData));
                \(functionName)(json);
                \(deletingScript);
            } catch(e) {
            
            }
            """
        }
        
        func writeDeletingScript(
            for functionName: String,
            if completed: Bool
        ) -> String {
            if completed {
                "delete window.\(functionName)"
            } else {
                ""
            }
        }
         //判断字符串是否为json
    func isValidJSON(_ string: String) -> Bool{
        if let data = string.data(using: .utf8){
            do{
                _ = try JSONSerialization.jsonObject(with: data,options: []);
                return true;
            }catch{
                return false;
            }
        }
        return false;
    }
    
    //添加转义
    func addEscapeCharactersToJSONString(_ string: String) -> String{
        var escapedString = string
        // 添加转义符号，转义常见的特殊字符
        escapedString = escapedString.replacingOccurrences(of: "\\", with: "\\\\")
        escapedString = escapedString.replacingOccurrences(of: "\"", with: "\\\"")
        escapedString = escapedString.replacingOccurrences(of: "\n", with: "\\n")
        escapedString = escapedString.replacingOccurrences(of: "\r", with: "\\r")
        escapedString = escapedString.replacingOccurrences(of: "\t", with: "\\t")
        escapedString = escapedString.replacingOccurrences(of: "\u{2028}", with: "\\u2028") // Line separator
        escapedString = escapedString.replacingOccurrences(of: "\u{2029}", with: "\\u2029") // Paragraph separator
        return escapedString
    }
    
    //字符串转换
    func clStringConvert(_ string:String) -> String{
        if(isValidJSON(string)){
            return addEscapeCharactersToJSONString(string);
        }else{
            return string;
        }
    }
    }
    
    open func handleRawInvocation(
        prompt: String,
        defaultText: String?
    ) -> JSON? {
        do {
            let signature = try getSignature(from: defaultText)
            let method = try getMethod(
                from: prompt,
                synchronous: signature.indicatesSynchronousCall
            )
            let invocation = IncomingInvocation(method: method, signature: signature)
            return handleIncomingInvocation(invocation)
        } catch {
            logger.logError(error)
            return nil
        }
    }
    
    open func getSignature(
        from defaultText: String?
    ) throws -> IncomingInvocation.Signature {
        try jsonSerializer.readParamters(from: defaultText)
    }
    
    open func getMethod(
        from prompt: String,
        synchronous: Bool
    ) throws -> Method {
        let raw = String(prompt.dropFirst(invocationPrefix.count))
        return try methodResolver.resolveMethodFromRaw(raw)
    }
    
    open var invocationPrefix: String {
        "_dsbridge="
    }
}
