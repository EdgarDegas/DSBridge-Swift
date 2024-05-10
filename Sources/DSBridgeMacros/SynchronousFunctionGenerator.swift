//
//  File.swift
//  
//
//  Created by iMoe Nya on 2024/4/26.
//

import SwiftSyntaxMacros
import SwiftSyntax

struct SynchronousFunctionGenerator: FunctionGenerating {
    let functions: [FunctionDeclSyntax]
    
    init(functions: [FunctionDeclSyntax]) {
        self.functions = functions.filter(\.isSynchronous)
    }
    
    var functionNameMapping: String {
        dictionaryLiteral(of: functions)
    }
    
    func generateHandling() -> String {
        let cases = generateCases()
        return if cases.isEmpty {
            "return nil"
        } else {
            """
            let function = synchronousFunctions[methodName]
            switch methodName {
            \(cases.joined(separator: "\n"))
            default:
                break
            }
            return nil
            """
        }
    }
    
    func convertionClauses(
        function: FunctionDeclSyntax,
        parameterTypes: [TypeSyntax]
    ) -> String {
        let returnType = returnType(of: function.signature)
        let closureTypeClause = closureTypeClause(
            parameterTypes: parameterTypes,
            returnType: returnType,
            hasAsyncSpecifier: false
        )
        let functionConvertion = guardConvertingFunction(
            to: closureTypeClause,
            else: "return nil"
        )
        if let parameterType = parameterTypes.first {
            let parameterConvertion = guardConvertingParameter(
                to: "\(parameterType)",
                else: "return nil"
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
            let calling = callingClause(
                hasParameter: hasParameter,
                shouldReturn: function.returns
            )
            return caseStatements(
                caseClause(name),
                convertion: convertion,
                defaultReturn: "nil",
                calling: calling
            )
        }
        
        func callingClause(
            hasParameter: Bool,
            shouldReturn: Bool
        ) -> String {
            let returnClause = if shouldReturn {
                "return "
            } else {
                ""
            }
            if hasParameter {
                return "\(returnClause)function(parameter)"
            } else {
                return "\(returnClause)function()"
            }
        }
    }
}
