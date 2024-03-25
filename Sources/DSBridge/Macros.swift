//
//  File.swift
//  
//
//  Created by iMoe Nya on 2024/3/24.
//

import Foundation

@attached(extension, conformances: InterfaceForJS)
@attached(member, names: arbitrary)
public macro Exposed() = #externalMacro(module: "DSBridgeMacros", type: "Exposed")

@attached(peer)
public macro unexposed() = #externalMacro(module: "DSBridgeMacros", type: "Unexposed")
