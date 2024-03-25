//
//  File.swift
//  
//
//  Created by iMoe Nya on 2024/3/23.
//

import Foundation

public protocol InvocationDispatching {
    var asyncResponseHandler: (AsyncResponse) -> Void { get set }
    func dispatch(_ invocation: IncomingInvocation) -> Response
    func addInterface(_ interface: ExposedInterface, by namespace: String)
    func hasMethod(_ method: Method) -> Bool
}

open class InvocationDispatcher: InvocationDispatching {
    open var interfaces: [String: any ExposedInterface] = [:]
    open var logger: any ErrorLogging = ErrorLogger.shared
    
    open var asyncResponseHandler: (AsyncResponse) -> Void
    
    open var respondAsynchronously: (AsyncResponse) -> Void {
        asyncResponseHandler
    }
    
    public init(
        asyncResponseHandler: @escaping (AsyncResponse) -> Void
    ) {
        self.asyncResponseHandler = asyncResponseHandler
    }
    
    open func addInterface(_ interface: ExposedInterface, by namespace: String) {
        interfaces[namespace] = interface
    }
    
    open func hasMethod(_ method: Method) -> Bool {
        getInterface(for: method) != nil
    }
    
    open func dispatch(_ invocation: IncomingInvocation) -> Response {
        let method = invocation.method
        guard let interface = getInterface(for: method) else {
            return .empty
        }
        if invocation.isSynchronous {
            let data = interface.handle(
                calling: method.name,
                with: invocation.signature.parameter
            )
            return Response(code: .success, data: data)
        } else {
            interface.handle(
                calling: method.name,
                with: invocation.signature.parameter
            ) { [weak self] resultAsJSON, completed in
                guard let self else { return }
                guard let functionName = invocation.signature.callbackFunctionName else {
                    logger.logMessage(
                        "Method marked non-synchronous has no callback.",
                        at: .error
                    )
                    return
                }
                let response = AsyncResponse(
                    functionName: functionName, 
                    data: resultAsJSON,
                    completed: completed
                )
                respondAsynchronously(response)
            }
            return .empty
        }
    }
    
    private func getInterface(for method: Method) -> ExposedInterface? {
        guard let interface = interfaces[method.namespace] else {
            logger.logError(
                Error.NameResolvingError.namespaceNotFound(method.namespace)
            )
            return nil
        }
        guard interface.hasMethod(named: method.name) else {
            logger.logError(
                Error.NameResolvingError.methodNotFound("\(method)")
            )
            return nil
        }
        return interface
    }
}
