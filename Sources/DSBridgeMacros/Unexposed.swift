//
//  File.swift
//  
//
//  Created by iMoe Nya on 2024/3/24.
//

import SwiftSyntax
import SwiftSyntaxMacros

public struct Unexposed: PeerMacro {
    static var attributeName: String {
        "unexposed"
    }
    
    @preconcurrency
    static func declarationMarkedUnexposed(
        _ declaration: FunctionDeclSyntax
    ) -> Bool {
        declaration.attributes.contains { attribute in
            attribute.as(AttributeSyntax.self)?.attributeName
                .as(IdentifierTypeSyntax.self)?
                .name
                .text
            == Unexposed.attributeName
        }
    }
    
    @preconcurrency
    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        providingPeersOf declaration: some SwiftSyntax.DeclSyntaxProtocol,
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [SwiftSyntax.DeclSyntax] {
        []
    }
}
