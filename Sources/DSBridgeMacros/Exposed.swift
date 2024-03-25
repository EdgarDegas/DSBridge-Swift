//
//  File.swift
//  
//
//  Created by iMoe Nya on 2024/3/24.
//

import SwiftSyntax
import SwiftSyntaxMacros

public struct Exposed: MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        [try! ExtensionDeclSyntax(
            "extension \(type): InterfaceForJS { }"
        )]
    }
    
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let functions = getFunctions(of: declaration)
        let dictionaryLiteral = dictionaryLiteral(of: functions)
        let synchronousCases = Self.casesForSynchronousFunctions(
            functions.filter(\.isSynchronous)
        )
        let asynchronousCases = Self.casesForAsynchronousFunctions(
            functions.filter(\.isAsynchronous)
        )
        return [
            """
            var exposed: [String: Any] {[
                \(raw: dictionaryLiteral)
            ]}
            """,
            """
            public func handle(
                calling methodName: String,
                with parameter: Any?
            ) -> Any? {
                switch methodName {
                \(raw: synchronousCases.joined(separator: "\n"))
                default:
                    return nil
                }
            }
            """,
            """
            public func handle(
                calling methodName: String,
                with parameter: Any?,
                completion: @escaping (Any?, Bool) -> Void
            ) {
                switch methodName {
                \(raw: asynchronousCases.joined(separator: "\n"))
                default:
                    break
                }
            }
            """,
            """
            public func hasMethod(named name: String) -> Bool {
                exposed.keys.contains(name)
            }
            """
        ]
    }
    
    static func getFunctions(
        of declaration: some DeclGroupSyntax
    ) -> [FunctionDeclSyntax] {
        let members = declaration.memberBlock.members
        return members
            .compactMap {
                $0.decl.as(FunctionDeclSyntax.self)
            }
            .filter {
                !Unexposed.declarationMarkedUnexposed($0)
            }
    }
    
    static func dictionaryLiteral(
        of functions: [FunctionDeclSyntax]
    ) -> String {
        let keyValues = functions.map {
            "\"\($0.name)\": \($0.name)"
        }
        return if keyValues.isEmpty {
            ""
        } else {
            keyValues.joined(separator: ",\n")
        }
    }
    
    static func guardConvertingFunction(
        _ name: String,
        to type: String,
        else: String
    ) -> String {
        `guard`(
            "let function = exposed[\(quoted(name))] as? \(type)",
            else: `else`
        )
    }
    
    static func guardConvertingParameter(
        to type: String,
        else: String
    ) -> String {
        `guard`(
            "let parameter = parameter as? \(type)",
            else: `else`
        )
    }
    
    static func `guard`(
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
    
    static func quoted(_ text: String) -> String {
        "\"\(text)\""
    }
    
    static func casesForAsynchronousFunctions(
        _ functions: [FunctionDeclSyntax]
    ) -> [String] {
        return functions.map { function in
            let numberOfParameters =
                function.signature.parameterClause.parameters.count
            return caseStatements(
                caseClause(function.name.text),
                convertion: convertionClauses(function: function),
                defaultReturn: "",
                calling: callingClause(numberOfParameters: numberOfParameters)
            )
        }
        
        func callingClause(numberOfParameters: Int) -> String {
            if numberOfParameters == 2 {
                "function(parameter, completion)"
            } else if numberOfParameters == 1 {
                "function(completion)"
            } else {
                "function()"
            }
        }
    }
    
    static func casesForSynchronousFunctions(
        _ functions: [FunctionDeclSyntax]
    ) -> [String] {
        return functions.map { function in
            let name = function.name.text
            let convertion = convertionClauses(
                function: function
            )
            let hasParameter = 
                !function.signature.parameterClause.parameters.isEmpty
            let calling = callingClause(
                hasParameter: hasParameter
            )
            return caseStatements(
                caseClause(name),
                convertion: convertion,
                defaultReturn: "nil",
                calling: calling
            )
        }
        
        func callingClause(hasParameter: Bool) -> String {
            if hasParameter {
                "return function(parameter)"
            } else {
                "return function()"
            }
        }
    }
    
    static func convertionClauses(
        function: FunctionDeclSyntax
    ) -> String {
        let parameterTypes = parameterTypes(of: function.signature)
        if function.isSynchronous {
            return convertionClauses(
                function: function, parameterTypes: parameterTypes
            )
        } else {
            return convertionClausesForAsynchronousFunction(
                function, parameterTypes: parameterTypes
            )
        }
    }
    
    static func convertionClauses(
        function: FunctionDeclSyntax,
        parameterTypes: [TypeSyntax]
    ) -> String {
        let returnType = returnType(of: function.signature)
        let closureTypeClause = closureTypeClause(
            parameterTypes: parameterTypes,
            returnType: returnType
        )
        let functionConvertion = guardConvertingFunction(
            function.name.text,
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
    
    static func convertionClausesForAsynchronousFunction(
        _ function: FunctionDeclSyntax,
        parameterTypes: [TypeSyntax]
    ) -> String {
        let closureTypeClause = closureTypeClause(
            parameterTypes: parameterTypes,
            returnType: "Void"
        )
        let functionConvertion = guardConvertingFunction(
            function.name.text,
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
    
    static func caseStatements(
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
    
    static func caseClause(_ name: String) -> String {
        "case \(quoted(name)):"
    }
    
    static func parameterTypes(
        of signature: FunctionSignatureSyntax
    ) -> [TypeSyntax] {
        signature.parameterClause.parameters.map { $0.type }
    }
    
    static func returnType(
        of signature: FunctionSignatureSyntax
    ) -> TypeSyntax {
        signature.returnClause?.type ?? "Void"
    }
    
    static func closureTypeClause(
        parameterTypes: [TypeSyntax],
        returnType: TypeSyntax
    ) -> String {
        let parameterClause = parameterTypes
            .map { "\($0)" }
            .joined(separator: ", ")
        return "(\(parameterClause)) -> \(returnType)"
    }
    
    static func getString(
        from expression: StringLiteralExprSyntax
    ) -> String? {
        guard expression.segments.count == 1 else {
            return nil
        }
        let segment = expression.segments.first!
        return segment.as(StringSegmentSyntax.self)?.content.text
    }
}
