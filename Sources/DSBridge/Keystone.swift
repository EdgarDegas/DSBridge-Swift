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
    func call<T>(
        _ methodName: String,
        with parameter: Any?,
        completion: ((Result<T, any Swift.Error>) -> Void)?
    )
    func addInterface(_ interface: ExposedInterface, by namespace: String)
    func removeInterface(by namespace: String)
    func hasJavaScriptMethod(named name: String, completion: @escaping (Bool) -> Void)
}

open class Keystone: KeystoneProtocol {
    private let jsonSerializer: any JSONSerializing
    private let methodResolver: any MethodResolving
    
    private lazy var predefinedExposedInterface =
    PredefinedInterface
    { [weak self] invocation in
        self?.handlePredefinedInvocation(invocation) ?? Void()
    }
    
    open var logger: ErrorLogging = sharedLogger
    
    open lazy var invocationDispatcher: any InvocationDispatching
        = InvocationDispatcher
    { [weak self] asyncResponse in
        self?.deliverAsyncResponse(asyncResponse)
    }
    
    open var evaluateJavaScript: (String) -> Void
    open var dismissalHandler: (() -> Void)?
    
    open lazy var javaScriptEvaluator: any JavaScriptEvaluating =
        JavaScriptEvaluator 
    { [weak self] script in
        self?.evaluateJavaScript(script)
    }
    
    public init(
        javaScriptEvaluationHandler: @escaping (String) -> Void,
        dismissalHandler: (() -> Void)?,
        jsonSerializer: any JSONSerializing = JSONSerializer(),
        methodResolver: any MethodResolving = MethodResolver()
    ) {
        self.evaluateJavaScript = javaScriptEvaluationHandler
        self.jsonSerializer = jsonSerializer
        self.methodResolver = methodResolver
        invocationDispatcher.addInterface(
            predefinedExposedInterface,
            by: PredefinedInterface.namespace
        )
    }
    
    open func call<T>(
        _ methodName: String,
        with parameter: Any?,
        completion: ((Result<T, any Swift.Error>) -> Void)?
    ) {
        do {
            let encoded = try encodeParameter(parameter)
            javaScriptEvaluator.call(methodName, with: encoded) {
                guard let result = $0 as? T else {
                    completion?(.failure(Error.CallingJS.returnTypeMismatch($0)))
                    return
                }
                completion?(.success(result))
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
            let has: Bool? = try? $0.get()
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
            dismissalHandler?()
        case .hasMethod(let rawMethod):
            do {
                let method = try methodResolver.resolveMethodFromRaw(
                    rawMethod
                )
                let result = invocationDispatcher.hasMethod(method)
                return result
            } catch {
                logger.logMessage(
                    "Failed to resolve method from text: \(rawMethod).",
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
            let encoded = try jsonSerializer.serialize(data)
            let deletingScript = writeDeletingScript(
                for: functionName, if: completed
            )
            evaluateJavaScript(
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
                \(functionName)(JSON.parse(decodeURIComponent(\(encodedData))));
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
