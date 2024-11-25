//
//  RecordingDirectoryPathResolver.swift
//  SwiftNetworkReplayExplorer
//
//  Created by Ivan Borinschi on 22.11.2024.
//

import os.log
import Foundation

protocol RecordingDirectoryPathResolver {
    func setTestDetails(filePath: String, folderName: String)
    func getRecordingDirectoryPath() -> String
    func getRecordingFolderName() -> String
    func removeRecordingDirectory() throws
    func createRecordingDirectoryIfNeed() throws
    func reset()
}

final class DefaultRecordingDirectoryPathResolver: RecordingDirectoryPathResolver {
    
    private var recordingDirectoryPath: String = ""
    private var recordingFolderName: String = ""
    
    var fileManager: FileManagerProtocol = DefaultFileManager()
    
    private let logger = OSLog(
        subsystem: Bundle.main.bundleIdentifier ?? "SwiftNetworkReplay", category: "DirectoryPathResolver"
    )
    
    func reset() {
        recordingDirectoryPath = ""
        recordingFolderName = ""
    }
    
    func setTestDetails(filePath: String, folderName: String) {
        recordingFolderName = folderName.replacingOccurrences(of: "()", with: "")
        let fileUrl = URL(fileURLWithPath: filePath, isDirectory: false)
        let testDirectoryUrl = fileUrl.deletingLastPathComponent()
            .appendingPathComponent("__NetworkReplay__")
            .appendingPathComponent(recordingFolderName)
        recordingDirectoryPath = testDirectoryUrl.path
    }
    
    func getRecordingDirectoryPath() -> String {
        return recordingDirectoryPath
    }
    
    func getRecordingFolderName() -> String {
        return recordingFolderName
    }
    
    func createRecordingDirectoryIfNeed() throws {
        if !fileManager.fileExists(atPath: getRecordingDirectoryPath()) {
            do {
                try fileManager.createDirectory(
                    atPath: getRecordingDirectoryPath(),
                    attributes: nil
                )
            } catch {
                os_log(
                    "Failed to create directory at path: %{public}@. Error: %{public}@",
                    log: logger,
                    type: .error, getRecordingDirectoryPath(),
                    error.localizedDescription
                )
                throw NSError(domain: "Directory Creation Failed", code: -1, userInfo: nil)
            }
        }
    }
    
    func removeRecordingDirectory() throws {
        if fileManager.fileExists(atPath: getRecordingDirectoryPath()) {
            do {
                try fileManager.removeItem(atPath: getRecordingDirectoryPath())
                os_log(
                    "Successfully removed recording directory at path: %{public}@",
                    log: logger,
                    type: .info,
                    getRecordingDirectoryPath()
                )
            } catch {
                os_log(
                    "Failed to remove recording directory at path: %{public}@. Error: %{public}@",
                    log: logger,
                    type: .error,
                    getRecordingDirectoryPath(),
                    error.localizedDescription
                )
                throw error
            }
        } else {
            os_log(
                "No recording directory exists at path: %{public}@",
                log: logger,
                type: .info,
                getRecordingDirectoryPath()
            )
        }
    }
}
