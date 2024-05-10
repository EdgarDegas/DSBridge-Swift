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
        let synchronousFunctionGenerator = SynchronousFunctionGenerator(
            functions: functions
        )
        let asynchronousFunctionGenerator = AsychronousFunctionGenerator(
            functions: functions
        )
        let structuredAsyncFunctionGenerator = StructuredAsyncFunctionGenerator(
            functions: functions
        )
        return [
            """
            var synchronousFunctions: [String: Any] {[
                \(raw: synchronousFunctionGenerator.functionNameMapping)
            ]}
            """,
            """
            var asynchronousFunctions: [String: Any] {[
                \(raw: asynchronousFunctionGenerator.functionNameMapping)
            ]}
            """,
            """
            var structuredAsyncFunctions: [String: Any] {[
                \(raw: structuredAsyncFunctionGenerator.functionNameMapping)
            ]}
            """,
            """
            public func handle(
                calling methodName: String,
                with parameter: Any?
            ) -> Any? {
                \(raw: synchronousFunctionGenerator.generateHandling())
            }
            """,
            """
            public func handle(
                calling methodName: String,
                with parameter: Any?,
                completion: @escaping (Any?, Bool) -> Void
            ) {
                if asynchronousFunctions.keys.contains(methodName) {
                    \(raw: asynchronousFunctionGenerator.generateHandling())
                } else {
                    \(raw: structuredAsyncFunctionGenerator.generateHandling())
                }
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
                    asynchronousFunctions.keys.contains(name) ||
                        structuredAsyncFunctions.keys.contains(name)
                } else {
                    synchronousFunctions.keys.contains(name) ||
                        asynchronousFunctions.keys.contains(name) ||
                        structuredAsyncFunctions.keys.contains(name)
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
}
