//
//  File.swift
//  
//
//  Created by user-new on 12/31/21.
//

import Foundation
import OSLog

@available(iOS 14.0, *)
extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier!

    /// Logs the view cycles like viewDidLoad.
    static let viewCycle = Logger(subsystem: subsystem, category: "viewcycle")
}

public struct LogHelper {
    //MARK: - LOG
    static func logError(err: String) {
        if #available(iOS 14.0, *) {
            Logger.viewCycle.error("\(err, privacy: .public)")
        } else {
            print("\(err)")
        }
    }
    
    static func logInfo(message: String) {
        if #available(iOS 14.0, *) {
            Logger.viewCycle.info("\(message)")
        } else {
            print("\(message)")
        }
    }
    
    static func logDebug(message: String) {
        if #available(iOS 14.0, *) {
            Logger.viewCycle.debug("\(message, privacy: .public)")
        } else {
            print("\(message)")
        }
    }
}


