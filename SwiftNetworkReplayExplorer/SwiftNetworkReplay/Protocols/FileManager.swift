//
//  FileManager.swift
//  SwiftNetworkReplay
//
//  Created by Ivan Borinschi on 22.11.2024.
//

import Foundation

protocol FileManagerProtocol {
    func fileExists(atPath path: String) -> Bool
    func createDirectory(atPath path: String, attributes: [FileAttributeKey : Any]?) throws
    func removeItem(atPath path: String) throws
}

final class DefaultFileManager: FileManagerProtocol {
    
    let fileManager: FileManager = .default
    
    func fileExists(atPath path: String) -> Bool {
        fileManager.fileExists(atPath: path)
    }
    
    func createDirectory(atPath path: String, attributes: [FileAttributeKey : Any]?) throws {
        try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: attributes)
    }
    
    func removeItem(atPath path: String) throws {
        try fileManager.removeItem(atPath: path)
    }
}
