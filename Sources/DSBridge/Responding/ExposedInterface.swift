//
//  File.swift
//  
//
//  Created by iMoe Nya on 2024/3/23.
//

import Foundation

public protocol ExposedInterface {
    func hasMethod(
        named name: String,
        isSynchronous: Bool?
    ) -> Bool
    func handle(calling methodName: String, with parameter: Any?) -> Any?
    func handle(calling methodName: String, with parameter: Any?, completion: @escaping (Any?, Bool) -> Void)
}
