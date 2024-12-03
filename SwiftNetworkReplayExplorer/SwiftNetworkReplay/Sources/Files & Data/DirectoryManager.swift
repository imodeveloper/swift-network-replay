//
//  RecordingDirectoryPathResolver.swift
//  SwiftNetworkReplayExplorer
//
//  Created by Ivan Borinschi on 22.11.2024.
//

import Foundation

public enum DirectoryManagerError: Error, LocalizedError {
    case directoryCreationFailed(String, Error?)
    case directoryRemovalFailed(String, Error?)
    
    public var errorDescription: String? {
        switch self {
        case .directoryCreationFailed(let path, let underlyingError):
            return "Failed to create directory at path: \(path)".addUnderliyngError(underlyingError)
        case .directoryRemovalFailed(let path, let underlyingError):
            return "Failed to remove directory at path: \(path)".addUnderliyngError(underlyingError)
        }
    }
}

public protocol DirectoryManager {
    
    func configure(directoryPath: String, folderName: String)
    func createDirectoryIfNeeded() throws
    func removeDirectoryIfExists() throws
    func reset()
    
    var directoryPath: String { get }
    var folderName: String { get }
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
                throw FrameworkLogger.logAndReturn(
                    error: DirectoryManagerError.directoryCreationFailed(directoryPath, error)
                )
            }
        }
    }
    
    public func removeDirectoryIfExists() throws {
        if fileManager.fileExists(atPath: directoryPath) {
            do {
                try fileManager.removeItem(atPath: directoryPath)
                FrameworkLogger.log(
                    "Successfully removed directory",
                    info: ["Path": directoryPath]
                )
            } catch {
                throw FrameworkLogger.logAndReturn(
                    error: DirectoryManagerError.directoryRemovalFailed(directoryPath, error)
                )
            }
        } else {
            FrameworkLogger.log(
                "No directory exists at path", info: ["Path": directoryPath]
            )
        }
    }
}
