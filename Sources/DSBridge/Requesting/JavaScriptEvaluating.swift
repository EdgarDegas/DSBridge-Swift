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

public final class JavaScriptEvaluator: JavaScriptEvaluating {
    private let perfromEvaluation: (JavaScript) -> Void
    private var incrementalID: Int = 0
    private var completionByID: [Int: Completion] = [:]
    private var waitingScripts: [String] = []
    private var initialized = false
    
    private let serialQueue = DispatchQueue(
        label: "JavaScriptEvaluator"
    )
    
    public init(evaluating: @escaping (JavaScript) -> Void) {
        self.perfromEvaluation = evaluating
    }
    
    public func evaluate(_ javaScript: JavaScript) {
        perfromEvaluation(javaScript)
    }
    
    public func initialize() {
        serialQueue.async { [weak self] in
            guard let self else { return }
            initialized = true
            evaluateWaitingScripts()
        }
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
    
    public func handleResponse(_ response: FromJS.Response) {
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
    
    private func evaluateWaitingScripts() {
        defer { waitingScripts = [] }
        for script in waitingScripts {
            evaluate(script)
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
        guard initialized else {
            waitingScripts.append(script)
            return
        }
        evaluate(script)
    }
}
