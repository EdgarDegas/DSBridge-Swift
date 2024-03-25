//
//  File.swift
//  
//
//  Created by iMoe Nya on 2024/3/24.
//

import Foundation
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

@main
struct Macros: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        Exposed.self,
        Unexposed.self
    ]
}
