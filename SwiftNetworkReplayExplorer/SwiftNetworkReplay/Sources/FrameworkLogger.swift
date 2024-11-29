//
//  FrameworkLogger.swift
//  SwiftNetworkReplayExplorer
//
//  Created by Ivan Borinschi on 29.11.2024.
//


import Foundation
import os.log

public struct FrameworkLogger {
    // Default logger is public so it can be used as a fallback
    public static let defaultLogger = OSLog(
        subsystem: Bundle.main.bundleIdentifier ?? "SwiftNetworkReplayLogger",
        category: "SwiftNetworkReplay"
    )
    
    public static func log(
        _ message: String,
        type: OSLogType = .info,
        info: [String: Any] = [:],
        logger: OSLog? = nil
    ) {
        // Use the provided logger or fallback to the default one
        let activeLogger = logger ?? defaultLogger
        
        var formattedMessage = "[SwiftNetworkReplay] \(message)"
        info.forEach { key, value in
            formattedMessage += "\n\(key): \(value)"
        }
        os_log("%{public}@", log: activeLogger, type: type, formattedMessage)
    }
}
