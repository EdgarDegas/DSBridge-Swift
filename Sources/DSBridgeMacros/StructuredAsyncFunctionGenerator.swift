//
//  File.swift
//  
//
//  Created by iMoe Nya on 2024/4/27.
//

import SwiftSyntax

struct StructuredAsyncFunctionGenerator: FunctionGenerating {
    let functions: [FunctionDeclSyntax]
    
    init(functions: [FunctionDeclSyntax]) {
        self.functions = functions.filter {
            $0.isAsychronous && $0.asynchronousCompletion == nil
        }
    }
    
    func generateHandling() -> String {
        let cases = generateCases()
        return if cases.isEmpty {
            ""
        } else {
            """
            let function = structuredAsyncFunctions[methodName]
            switch methodName {
            \(cases.joined(separator: "\n"))
            default:
                break
            }
            """
        }
    }
    
    func convertionClauses(
        function: SwiftSyntax.FunctionDeclSyntax,
        parameterTypes: [SwiftSyntax.TypeSyntax]
    ) -> String {
        let returnType = returnType(of: function.signature)
        let closureTypeClause = closureTypeClause(
            parameterTypes: parameterTypes,
            returnType: returnType,
            hasAsyncSpecifier: true
        )
        let functionConvertion = guardConvertingFunction(
            to: closureTypeClause,
            else: "return"
        )
        if let parameterType = parameterTypes.first {
            let parameterConvertion = guardConvertingParameter(
                to: "\(parameterType)",
                else: "return"
            )
            return """
            \(functionConvertion)
            \(parameterConvertion)
            """
        } else {
            return functionConvertion
        }
    }
    
    func generateCases() -> [String] {
        return functions.map { function in
            let name = function.name.text
            let convertion = convertionClauses(
                function: function
            )
            let hasParameter =
                !function.signature.parameterClause.parameters.isEmpty
            return caseStatements(
                caseClause(name),
                convertion: convertion,
                defaultReturn: "nil",
                calling: """
                Task {
                    \(callingClause(hasParameter: hasParameter, returns: function.returns))
                    \(completionCallingClause(hasReturnValue: function.returns))
                }
                """
            )
        }
        
        func callingClause(
            hasParameter: Bool,
            returns: Bool
        ) -> String {
            let exec = if hasParameter {
                "await function(parameter)"
            } else {
                "await function()"
            }
            return if returns {
                "let result = \(exec)"
            } else {
                "\(exec)"
            }
        }
        
        func completionCallingClause(hasReturnValue: Bool) -> String {
            if hasReturnValue {
                "completion(result, true)"
            } else {
                "completion(nil, true)"
            }
        }
    }
    
    var functionNameMapping: String {
        dictionaryLiteral(of: functions)
    }
}
