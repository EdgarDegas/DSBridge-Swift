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
        !isAsychronous
    }
    
    var isAsychronous: Bool {
        if asynchronousCompletion != nil {
            return true
        }
        let hasAsyncSpecifier = signature.effectSpecifiers?.asyncSpecifier != nil
        return hasAsyncSpecifier
    }
    
    var asynchronousCompletion: FunctionTypeSyntax? {
        guard
            !returns,
            let lastParameter = signature.parameterClause.parameters.last
        else {
            return nil
        }
        if let completion = lastParameter.type.as(FunctionTypeSyntax.self) {
            return completion
        } else if let type = lastParameter.type
            .as(AttributedTypeSyntax.self)?
            .baseType
        {
            return type.as(FunctionTypeSyntax.self)
        } else {
            return nil
        }
    }
}
