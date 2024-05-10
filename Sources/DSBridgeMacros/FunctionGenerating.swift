//
//  File.swift
//  
//
//  Created by iMoe Nya on 2024/4/26.
//

import SwiftSyntax

protocol FunctionGenerating {
    func convertionClauses(
        function: FunctionDeclSyntax,
        parameterTypes: [TypeSyntax]
    ) -> String
    
    func generateCases() -> [String]
    
    var functionNameMapping: String { get }
    
    func generateHandling() -> String
}

extension FunctionGenerating {
    func dictionaryLiteral(
        of functions: [FunctionDeclSyntax]
    ) -> String {
        let keyValues = functions.map {
            "\"\($0.name)\": \($0.name)"
        }
        return if keyValues.isEmpty {
            ":"
        } else {
            keyValues.joined(separator: ",\n")
        }
    }
    
    func convertionClauses(
        function: FunctionDeclSyntax
    ) -> String {
        let parameterTypes = parameterTypes(of: function.signature)
        return convertionClauses(
            function: function, parameterTypes: parameterTypes
        )
    }
    
    func `guard`(
        _ text: String,
        else: String
    ) -> String {
        """
        guard
            \(text)
        else {
            \(`else`)
        }
        """
    }
    
    func guardConvertingParameter(
        to type: String,
        else: String
    ) -> String {
        `guard`(
            "let parameter = parameter as? \(type)",
            else: `else`
        )
    }
    
    func caseStatements(
        _ caseClause: String,
        convertion: String,
        defaultReturn: String,
        calling: String
    ) -> String {
        """
        \(caseClause)
            \(convertion)
            \(calling)
        """
    }
    
    func guardConvertingFunction(
        to type: String,
        else: String
    ) -> String {
        `guard`(
            "let function = function as? \(type)",
            else: `else`
        )
    }

    func caseClause(_ name: String) -> String {
        "case \(quoted(name)):"
    }
    
    func parameterTypes(
        of signature: FunctionSignatureSyntax
    ) -> [TypeSyntax] {
        signature.parameterClause.parameters.map { $0.type }
    }
    
    func returnType(
        of signature: FunctionSignatureSyntax
    ) -> TypeSyntax {
        signature.returnClause?.type ?? "Void"
    }
    
    func closureTypeClause(
        parameterTypes: [TypeSyntax],
        returnType: TypeSyntax,
        hasAsyncSpecifier: Bool
    ) -> String {
        let parameterClause = parameterTypes
            .map { "\($0)" }
            .joined(separator: ", ")
        let asyncSpecifierMaybe = if hasAsyncSpecifier {
            "async "
        } else {
            ""
        }
        return "(\(parameterClause)) \(asyncSpecifierMaybe)-> \(returnType)"
    }
    
    func quoted(_ text: String) -> String {
        "\"\(text)\""
    }
}
