//
//  File.swift
//  
//
//  Created by iMoe Nya on 2024/3/20.
//

import WebKit
import CHelper
import Runtime
import Darwin

/// $s8DSBridge10UIDelegateCN
open class UIDelegate {

}


struct FunctionMetadataLayout {
    var _kind: Int
    var flags: Int
    var argumentVector: Vector<Any.Type>
}


struct Vector<Element> {
    
    var element: Element
    
    mutating func vector(n: Int) -> UnsafeBufferPointer<Element> {
        return withUnsafePointer(to: &self) {
            $0.withMemoryRebound(to: Element.self, capacity: 1) { start in
                return start.buffer(n: n)
            }
        }
    }
    
    mutating func element(at i: Int) -> UnsafeMutablePointer<Element> {
        return withUnsafePointer(to: &self) {
            return $0.raw.assumingMemoryBound(to: Element.self).advanced(by: i).mutable
        }
    }
}
extension UnsafePointer {
    
    var raw: UnsafeRawPointer {
        return UnsafeRawPointer(self)
    }
    
    var mutable: UnsafeMutablePointer<Pointee> {
        return UnsafeMutablePointer<Pointee>(mutating: self)
    }
    
    func buffer(n: Int) -> UnsafeBufferPointer<Pointee> {
        return UnsafeBufferPointer(start: self, count: n)
    }
}
