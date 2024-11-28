//
//  RecordingDirectoryPathResolver.swift
//  SwiftNetworkReplayExplorer
//
//  Created by Ivan Borinschi on 22.11.2024.
//

import os.log
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
    
    private let logger = OSLog(
        subsystem: Bundle.main.bundleIdentifier ?? "SwiftNetworkReplay",
        category: "DirectoryManager"
    )
    
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
            } catch {
                os_log(
                    "Failed to create directory at path: %{public}@. Error: %{public}@",
                    log: logger,
                    type: .error,
                    directoryPath,
                    error.localizedDescription
                )
                throw NSError(domain: "Directory Creation Failed", code: -1, userInfo: nil)
            }
        }
    }
    
    public func removeDirectory() throws {
        if fileManager.fileExists(atPath: directoryPath) {
            do {
                try fileManager.removeItem(atPath: directoryPath)
                os_log(
                    "Successfully removed directory at path: %{public}@",
                    log: logger,
                    type: .info,
                    directoryPath
                )
            } catch {
                os_log(
                    "Failed to remove directory at path: %{public}@. Error: %{public}@",
                    log: logger,
                    type: .error,
                    directoryPath,
                    error.localizedDescription
                )
                throw error
            }
        } else {
            os_log(
                "No directory exists at path: %{public}@",
                log: logger,
                type: .info,
                directoryPath
            )
        }
    }
}
