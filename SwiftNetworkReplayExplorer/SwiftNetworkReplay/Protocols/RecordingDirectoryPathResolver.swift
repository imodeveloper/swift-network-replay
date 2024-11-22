//
//  RecordingDirectoryPathResolver.swift
//  SwiftNetworkReplayExplorer
//
//  Created by Ivan Borinschi on 22.11.2024.
//

protocol RecordingDirectoryPathResolver {
    func setTestDetails(filePath: String, folderName: String)
    func getRecordingDirectoryPath() -> String
    func getRecordingFolderName() -> String
}


final class DefaultRecordingDirectoryPathResolver: RecordingDirectoryPathResolver {
    
    private var recordingDirectoryPath: String = ""
    private var recordingFolderName: String = ""
    
    func setTestDetails(filePath: String, folderName: String) {
        recordingFolderName = folderName.replacingOccurrences(of: "()", with: "")
        let fileUrl = URL(fileURLWithPath: filePath, isDirectory: false)
        let testDirectoryUrl = fileUrl.deletingLastPathComponent()
            .appendingPathComponent("__TestData__")
            .appendingPathComponent(recordingFolderName)
        recordingDirectoryPath = testDirectoryUrl.path
    }
    
    func getRecordingDirectoryPath() -> String {
        return recordingDirectoryPath
    }
    
    func getRecordingFolderName() -> String {
        return recordingFolderName
    }
}
