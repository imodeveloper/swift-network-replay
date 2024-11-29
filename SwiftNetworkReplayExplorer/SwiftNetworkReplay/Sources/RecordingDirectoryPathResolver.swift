//
//  RecordingDirectoryPathResolver.swift
//  SwiftNetworkReplayExplorer
//
//  Created by Ivan Borinschi on 22.11.2024.
//

import Foundation

public protocol DirectoryManager {
    func configure(directoryPath: String, folderName: String)
    var directoryPath: String { get }
    var folderName: String { get }
    func createDirectoryIfNeeded() throws
    func removeDirectory() throws
    func reset()
}

public final class DefaultDirectoryManager: DirectoryManager {
    
    private var _directoryPath: String = ""
    private var _folderName: String = ""
    
    var fileManager: FileManagerProtocol = DefaultFileManager()
        
    public func reset() {
        _directoryPath = ""
        _folderName = ""
    }
    
    public func configure(directoryPath: String, folderName: String) {
        _folderName = folderName.replacingOccurrences(of: "()", with: "")
        let directoryUrl = URL(fileURLWithPath: directoryPath, isDirectory: false)
        let finalDirectoryUrl = directoryUrl.deletingLastPathComponent()
            .appendingPathComponent("__NetworkReplay__")
            .appendingPathComponent(_folderName)
        _directoryPath = finalDirectoryUrl.path
    }
    
    public var directoryPath: String {
        return _directoryPath
    }
    
    public var folderName: String {
        return _folderName
    }
    
    public func createDirectoryIfNeeded() throws {
        if !fileManager.fileExists(atPath: directoryPath) {
            do {
                try fileManager.createDirectory(
                    atPath: directoryPath,
                    attributes: nil
                )
                FrameworkLogger.log(
                    "Successfully created directory",
                    info: ["Path": directoryPath]
                )
            } catch {
                FrameworkLogger.log(
                    "Failed to create directory",
                    type: .error,
                    info: ["Path": directoryPath, "Error": error.localizedDescription]
                )
                throw NSError(domain: "Directory Creation Failed", code: -1, userInfo: nil)
            }
        }
    }
    
    public func removeDirectory() throws {
        if fileManager.fileExists(atPath: directoryPath) {
            do {
                try fileManager.removeItem(atPath: directoryPath)
                FrameworkLogger.log(
                    "Successfully removed directory",
                    info: ["Path": directoryPath]
                )
            } catch {
                FrameworkLogger.log(
                    "Failed to remove directory",
                    type: .error,
                    info: ["Path": directoryPath, "Error": error.localizedDescription]
                )
                throw error
            }
        } else {
            FrameworkLogger.log(
                "No directory exists at path", info: ["Path": directoryPath]
            )
        }
    }
}
