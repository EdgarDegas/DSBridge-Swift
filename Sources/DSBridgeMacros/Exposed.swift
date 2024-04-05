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
            "extension \(type): ExposedInterface { }"
        )]
    }
    
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let functions = getFunctions(of: declaration)
        let synchronousFunctions = functions.filter(\.isSynchronous)
        let asynchronousFunctionAndCompletions: [
            (FunctionDeclSyntax, FunctionTypeSyntax)
        ] = functions
            .lazy
            .filter {
                $0.asynchronousCompletion != nil
            }
            .map {
                ($0, $0.asynchronousCompletion!)
            }
        let synchronousCases = Self.casesForSynchronousFunctions(
            synchronousFunctions
        )
        let synchronousHandlingBody = if synchronousCases.isEmpty {
            "return nil"
        } else {
            """
            let function = synchronousFunctions[methodName]
            switch methodName {
            \(synchronousCases.joined(separator: "\n"))
            default:
                break
            }
            return nil
            """
        }
        let asynchronousCases = Self.casesForAsynchronousFunctions(
            asynchronousFunctionAndCompletions
        )
        let asynchronousHandlingBody = if asynchronousCases.isEmpty {
            ""
        } else {
            """
            let function = asynchronousFunctions[methodName]
            switch methodName {
            \(asynchronousCases.joined(separator: "\n"))
            default:
                break
            }
            """
        }
        return [
            """
            var synchronousFunctions: [String: Any] {[
                \(raw: dictionaryLiteral(of: synchronousFunctions))
            ]}
            """,
            """
            var asynchronousFunctions: [String: Any] {[
                \(raw: dictionaryLiteral(of: asynchronousFunctionAndCompletions.map(\.0)))
            ]}
            """,
            """
            public func handle(
                calling methodName: String,
                with parameter: Any?
            ) -> Any? {
                \(raw: synchronousHandlingBody)
            }
            """,
            """
            public func handle(
                calling methodName: String,
                with parameter: Any?,
                completion: @escaping (Any?, Bool) -> Void
            ) {
                \(raw: asynchronousHandlingBody)
            }
            """,
            """
            public func hasMethod(
                named name: String,
                isSynchronous: Bool?
            ) -> Bool {
                if isSynchronous == true {
                    synchronousFunctions.keys.contains(name)
                } else if isSynchronous == false {
                    asynchronousFunctions.keys.contains(name)
                } else {
                    synchronousFunctions.keys.contains(name) ||
                        asynchronousFunctions.keys.contains(name)
                }
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
            ":"
        } else {
            keyValues.joined(separator: ",\n")
        }
    }
    
    static func guardConvertingFunction(
        to type: String,
        else: String
    ) -> String {
        `guard`(
            "let function = function as? \(type)",
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
        _ functions: [(FunctionDeclSyntax, FunctionTypeSyntax)]
    ) -> [String] {
        return functions.map { (function, completion) in
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
