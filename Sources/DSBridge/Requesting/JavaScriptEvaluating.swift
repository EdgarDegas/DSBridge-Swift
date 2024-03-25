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
    func handleResponse(_ response: FromJS.Response)
    func initialize()
}

public typealias JavaScript = String

open class JavaScriptEvaluator: JavaScriptEvaluating {
    private let evaluating: (JavaScript) -> Void
    private var incrementalID: Int = 0
    private var completionByID: [Int: Completion] = [:]
    private var waitingScripts: [String] = []
    private var initialized = false
    
    /// Serial queue to access properties and evaluate scripts.
    private let serialQueue = DispatchQueue(
        label: "JavaScriptEvaluator",
        target: .main
    )
    
    public init(evaluating: @escaping (JavaScript) -> Void) {
        self.evaluating = evaluating
    }
    
    open func evaluate(_ javaScript: JavaScript) {
        serialQueue.async { [weak self] in
            guard let self else { return }
            performEvaluation(javaScript)
        }
    }
    
    open func initialize() {
        serialQueue.async { [weak self] in
            guard let self else { return }
            initialized = true
            evaluateWaitingScripts()
        }
    }
    
    open func call(
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
    
    open func handleResponse(_ response: FromJS.Response) {
        serialQueue.async { [weak self] in
            guard 
                let self,
                let completion = completionByID[response.id]
            else {
                return
            }
            defer {
                if response.completed {
                    completionByID.removeValue(forKey: response.id)
                }
            }
            completion(response.data)
        }
    }
    
    private func performEvaluation(_ script: String) {
        guard initialized else {
            waitingScripts.append(script)
            return
        }
        evaluating(script)
    }
    
    private func evaluateWaitingScripts() {
        let scripts = waitingScripts
        waitingScripts = []
        for script in scripts {
            performEvaluation(script)
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
        performEvaluation(script)
    }
}
