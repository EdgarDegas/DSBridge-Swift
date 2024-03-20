//
//  File.swift
//  
//
//  Created by iMoe Nya on 2024/3/23.
//

import Foundation

public protocol JavaScriptEvaluating: AnyObject {
    typealias Completion = (Any) -> Void
    
    func evaluate(_ javaScript: JavaScript)
    func call(
        _ functionName: String,
        with parameter: JSON,
        completion: Completion?
    )
    func handleCallback(_ callback: Callback)
}

public typealias JavaScript = String

public final class JavaScriptEvaluator: JavaScriptEvaluating {
    private let perfromEvaluation: (JavaScript) -> Void
    private var incrementalID: Int = 0
    private var completionByID: [Int: Completion] = [:]
    
    private let serialQueue = DispatchQueue(
        label: "JavaScriptEvaluator"
    )
    
    public init(evaluating: @escaping (JavaScript) -> Void) {
        self.perfromEvaluation = evaluating
    }
    
    public func evaluate(_ javaScript: JavaScript) {
        perfromEvaluation(javaScript)
    }
    
    public func call(
        _ functionName: String,
        with parameter: JSON,
        completion: Completion?
    ) {
        serialQueue.async { [weak self] in
            guard let self else { return }
            defer { incrementalID += 1 }
            let id = incrementalID
            if let completion {
                completionByID[id] = completion
            }
            call(functionName, with: parameter, id: id)
        }
    }
    
    public func handleCallback(_ callback: Callback) {
        serialQueue.async { [weak self] in
            guard 
                let self,
                let completion = completionByID[callback.id]
            else {
                return
            }
            defer {
                if callback.completed {
                    completionByID.removeValue(forKey: callback.id)
                }
            }
            completion(callback.data)
        }
    }
    
    private func call(
        _ functionName: String,
        with parameter: JSON,
        id: Int
    ) {
        let message = """
        {
            "method": "\(functionName)",
            "callbackId": \(id),
            "data": \(parameter)
        }
        """
        let script = "window._handleMessageFromNative(\(message))"
        evaluate(script)
    }
}
