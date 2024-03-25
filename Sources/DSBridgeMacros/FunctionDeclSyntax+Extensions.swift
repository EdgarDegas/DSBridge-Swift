//
//  File.swift
//  
//
//  Created by iMoe Nya on 2024/3/25.
//

import SwiftSyntax

extension FunctionDeclSyntax {
    var returns: Bool {
        signature.returnClause != nil
    }
    
    var isSynchronous: Bool {
        !isAsynchronous
    }
    
    var isAsynchronous: Bool {
        guard
            !returns,
            let lastParameter = signature.parameterClause.parameters.last
        else {
            return false
        }
        if lastParameter.type.is(FunctionTypeSyntax.self) {
            return true
        } else if let type = lastParameter.type
            .as(AttributedTypeSyntax.self)?
            .baseType
        {
            return type.is(FunctionTypeSyntax.self)
        } else {
            return false
        }
    }
}
