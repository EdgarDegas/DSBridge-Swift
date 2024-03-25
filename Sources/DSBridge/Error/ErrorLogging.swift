//
//  File.swift
//  
//
//  Created by iMoe Nya on 2024/3/23.
//

import Foundation
import os

public protocol ErrorLogging {
    func logError(_ error: any Swift.Error)
    func logError(_ error: any Swift.Error, into category: String?)
    func logMessage(_ message: String, at level: OSLogType)
    func logMessage(_ message: String, at level: OSLogType, into category: String?)
}

public final class ErrorLogger: ErrorLogging {
    static let shared = ErrorLogger()
    
    public var logByCategory: [String: OSLog] = [:]
    public var loggerByCategory: [String: Any] = [:]
    
    public static var subsystem: String {
        packageUniqueID
    }
    
    public func logError(_ error: any Swift.Error) {
        if let category = (error as? LoggableError)?.category {
            logError(error, into: category)
        } else {
            logError(error, into: nil)
        }
    }
    
    public func logError(_ error: any Swift.Error, into category: String?) {
        logMessage("\(error)", at: .error, into: category)
    }
    
    public func logMessage(_ message: String, at level: OSLogType) {
        logMessage(message, at: level, into: nil)
    }
    
    public func logMessage(_ message: String, at level: OSLogType, into category: String?) {
        let category = category ?? ""
        if #available(iOS 14.0, *) {
            let logger = getOrCreateLogger(by: category)
            logger.log(level: level, "\(message)")
        } else {
            let log = getOrCreateLog(by: category)
            os_log(.error, log: log, "", "\(message)")
        }
    }
    
    @available(iOS 14.0, *)
    private func getOrCreateLogger(by category: String) -> Logger {
        loggerByCategory[
            category,
            default: Logger(subsystem: Self.subsystem, category: category)
        ] as! Logger
    }
    
    private func getOrCreateLog(by category: String) -> OSLog {
        logByCategory[
            category,
            default: OSLog(subsystem: Self.subsystem, category: category)
        ]
    }
}
