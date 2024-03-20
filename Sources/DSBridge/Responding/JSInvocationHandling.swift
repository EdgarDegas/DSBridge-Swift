//
//  File.swift
//  
//
//  Created by iMoe Nya on 2024/3/23.
//

import Foundation

public protocol JSInvocationHandling {
    func handle(
        _ invocation: JSInvocation,
        callback: ((Response, Bool) -> Void)?
    ) -> Response
    
    func addInterface(_ interface: InterfaceForJS, by namespace: String)
}

open class JSInvocationHandler: JSInvocationHandling {
    open var interfaces: [String: any InterfaceForJS] = [:]
    open var logger: any ErrorLogging = ErrorLogger.shared
    
    public init(
        interfaces: [String: any InterfaceForJS] = [:]
    ) {
        self.interfaces = interfaces
    }
    
    open func addInterface(_ interface: InterfaceForJS, by namespace: String) {
        interfaces[namespace] = interface
    }
    
    open func handle(
        _ invocation: JSInvocation,
        callback: ((Response, Bool) -> Void)?
    ) -> Response {
        let method = invocation.method
        guard let interface = interfaces[method.namespace] else {
            logger.logError(
                Error.NameResolvingError.namespaceNotFound(method.namespace)
            )
            return .empty
        }
        guard interface.hasMethod(named: method.name) else {
            logger.logError(
                Error.NameResolvingError.methodNotFound(method.fullname)
            )
            return .empty
        }
        if method.isSynchronous {
            let data = interface.handle(
                calling: method.name,
                with: invocation.signature.parameter
            )
            return Response(code: .success, data: data)
        } else {
            interface.handle(
                calling: method.name,
                with: invocation.signature.parameter
            ) { resultAsJSON, completed in
                let returnValue = Response(
                    code: .success, data: resultAsJSON
                )
                callback?(returnValue, completed)
            }
            return .empty
        }
    }
}
