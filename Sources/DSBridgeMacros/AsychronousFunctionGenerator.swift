//
//  File.swift
//  
//
//  Created by iMoe Nya on 2024/4/26.
//

import SwiftSyntax

struct AsychronousFunctionGenerator: FunctionGenerating {
    func generateHandling() -> String {
        let cases = generateCases()
        return if cases.isEmpty {
            ""
        } else {
            """
            let function = asynchronousFunctions[methodName]
            switch methodName {
            \(cases.joined(separator: "\n"))
            default:
                break
            }
            """
        }
    }
    
    let functionAndCompletions: [
        (function: FunctionDeclSyntax, type: FunctionTypeSyntax)
    ]
    
    init(functions: [FunctionDeclSyntax]) {
        self.functionAndCompletions = functions
            .lazy
            .filter {
                $0.asynchronousCompletion != nil
            }
            .map {
                ($0, $0.asynchronousCompletion!)
            }
    }
    
    var functionNameMapping: String {
        dictionaryLiteral(of: functionAndCompletions.map(\.function))
    }
    
    func convertionClauses(
        function: FunctionDeclSyntax,
        parameterTypes: [TypeSyntax]
    ) -> String {
        let closureTypeClause = closureTypeClause(
            parameterTypes: parameterTypes,
            returnType: "Void",
            hasAsyncSpecifier: false
        )
        let functionConvertion = guardConvertingFunction(
            to: closureTypeClause,
            else: "return"
        )
        if
            parameterTypes.count == 2,
            let parameterType = parameterTypes.first
        {
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
        return functionAndCompletions.map { (function, completion) in
            let numberOfParameters =
                function.signature.parameterClause.parameters.count
            let numberOfParametersInCompletion =
                completion.parameters.count
            return caseStatements(
                caseClause(function.name.text),
                convertion: convertionClauses(function: function),
                defaultReturn: "",
                calling: callingClause(
                    numberOfParameters: numberOfParameters,
                    numberOfParametersInCompletion:
                        numberOfParametersInCompletion
                )
            )
        }
        
        func callingClause(
            numberOfParameters: Int,
            numberOfParametersInCompletion: Int
        ) -> String {
            let completionCallingClause = completionCallingClause(
                numberOfParameters: numberOfParametersInCompletion
            )
            return if numberOfParameters == 2 {
                """
                function(parameter) {
                    \(completionCallingClause)
                }
                """
            } else if numberOfParameters == 1 {
                """
                function {
                    \(completionCallingClause)
                }
                """
            } else {
                "function()"
            }
            
            func completionCallingClause(
                numberOfParameters: Int
            ) -> String {
                if numberOfParameters == 1 {
                    // the second parameter defaults to true
                    "completion($0, true)"
                } else {
                    "completion($0, $1)"
                }
            }
        }
    }
}
