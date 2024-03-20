//
//  File.swift
//  
//
//  Created by iMoe Nya on 2024/3/24.
//

import SwiftSyntax
import SwiftSyntaxMacros

public struct Exposed: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let classDecl = declaration.as(ClassDeclSyntax.self)!
        let members = classDecl.memberBlock.members
        let names = members
            .compactMap {
                $0.decl.as(FunctionDeclSyntax.self)
            }
            .filter {
                !$0.attributes.contains { attribute in
                    attribute.as(AttributeSyntax.self)?.attributeName
                        .as(IdentifierTypeSyntax.self)?
                        .name
                        .text
                    == Unexposed.attributeName
                }
            }
            .map {
                "\"\($0.name)\": (\($0.name))"
            }
        let dict = if names.isEmpty {
            ""
        } else {
            names.joined(separator: ",\n")
        }
        return [
            """
            var exposed: [String: Any] {[
                \(raw: dict)
            ]}
            """,
            """
            public func handle(
                calling methodName: String,
                with parameter: Any?
            ) -> Any? {
                guard let function = exposed[methodName] as?
                    (Any?) -> Any?
                else {
                    return nil
                }
                return function(parameter)
            }
            """,
            """
            public func handle(
                calling methodName: String,
                with parameter: Any?,
                completion: @escaping (Any?, Bool) -> Void
            ) {
                guard let function = exposed[methodName] as?
                    (Any?, Any) -> Void
                else {
                    return
                }
                function(parameter, completion)
            }
            """,
            """
            public func hasMethod(named name: String) -> Bool {
                exposed.keys.contains(name)
            }
            """
        ]
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
