//
//  URLSessionReplay.swift
//  SwiftNetworkReplay
//
//  Created by Ivan Borinschi on 22.11.2024.
//

import os.log
import Foundation

public protocol URLSessionReplay {
    func setSession(dirrectoryPath: String, sessionFolderName: String)
    func performRequestAndRecord(request: URLRequest) async throws -> (httpURLResponse: HTTPURLResponse, responseData: Data)
    func replayRecordFor(request: URLRequest) async throws -> (httpURLResponse: HTTPURLResponse, responseData: Data)
    func isSessionReady() -> Bool
    func doesRecordingExistsFor(request: URLRequest) -> Bool
    func getFileUrl(request: URLRequest) -> URL
    func removeRecordingSessionFolder() throws
}

public final class DefaultURLSessionReplay: URLSessionReplay {
    
    private var session: URLSession = .shared
    
    var dataTaskSerializer: HTTPDataTaskSerializer = DefaultHTTPDataTaskSerializer()
    var fileManager: FileManagerProtocol = DefaultFileManager()
    var recordingDirectoryManager: DirectoryManager = DefaultDirectoryManager()
    var fileNameResolver: RequestFileNameGenerator = DefaultRequestFileNameGenerator()
    
    private let logger = OSLog(
        subsystem: Bundle.main.bundleIdentifier ?? "SwiftNetworkReplay", category: "SessionReplay"
    )
    
    public func doesRecordingExistsFor(request: URLRequest) -> Bool {
        let fileURL = getFileUrl(request: request)
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    public func isSessionReady() -> Bool {
        if recordingDirectoryManager.directoryPath.isEmpty {
            os_log(
                "Error: recordingDirectoryPath is not set.",
                log: logger,
                type: .error
            )
            return false
        }
        return true
    }
    
    /// Performs a request, records the response, and replays it.
    /// - Parameters:
    ///   - fileURL: The file URL to save the recorded response.
    ///   - request: The URL request to execute.
    /// - Returns: A tuple containing the HTTP URL response and the response data.
    /// - Throws: An error if the operation fails.
    public func performRequestAndRecord(request: URLRequest) async throws -> (httpURLResponse: HTTPURLResponse, responseData: Data) {
        
        do {
            // Ensure the recording directory exists.
            try recordingDirectoryManager.createDirectoryIfNeeded()
        } catch {
            throw error
        }

        // Update the request with a custom header.
        var newRequest = request
        newRequest.setValue("true", forHTTPHeaderField: "X-SwiftNetworkReplay")
        
        // Execute the request using async/await.
        let (responseData, httpResponse) = try await session.asyncData(for: newRequest)

        guard let httpResponse = httpResponse as? HTTPURLResponse else {
            throw NSError(domain: "Invalid Response", code: -1, userInfo: nil)
        }
        
        // Process and record the response.
        let recordedResponseData = try dataTaskSerializer.encode(
            request: newRequest,
            responseData: responseData,
            httpResponse: httpResponse
        )
        
        let fileUrl = getFileUrl(request: newRequest)
        try recordedResponseData.write(to: fileUrl, options: .atomic)
        
        os_log(
            "Successfully recorded response for URL: %{public}@ to file: %{public}@",
            log: logger,
            type: .info,
            request.url?.absoluteString ?? "Unknown URL",
            fileUrl.absoluteString
        )
        
        // Replay the response and return the result.
        return try await replayRecordFor(request: newRequest)
    }
    
    public func replayRecordFor(request: URLRequest) async throws -> (httpURLResponse: HTTPURLResponse, responseData: Data) {
        
        let recordedData = try Data(contentsOf: getFileUrl(request: request))
        
        guard let result = try? dataTaskSerializer.decode(request: request, data: recordedData) else {
            os_log(
                "Failed to parse recorded data for URL: %{public}@",
                log: logger,
                type: .error,
                request.url?.absoluteString ?? "Missing URL"
            )
            throw NSError(domain: "Invalid Recorded Data", code: -2, userInfo: nil)
        }
        
        return (
            httpURLResponse: result.httpURLResponse,
            responseData: result.responseData
        )
    }
    
    public func getFileUrl(request: URLRequest) -> URL {
        let fileName = fileNameResolver.generateFileName(
            for: request,
            aiditionalName: recordingDirectoryManager.folderName
        )
        return URL(
            fileURLWithPath: recordingDirectoryManager.directoryPath
        ).appendingPathComponent(fileName)
    }
    
    public func removeRecordingSessionFolder() throws {
        try recordingDirectoryManager.removeDirectory()
    }
    
    public func setSession(dirrectoryPath: String, sessionFolderName: String) {
        recordingDirectoryManager.configure(
            directoryPath: dirrectoryPath,
            folderName: sessionFolderName
        )
    }
}

// MARK: - Helper Extension for URLSession

extension URLSession {
    func asyncData(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let task = self.dataTask(with: request) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let data = data, let response = response {
                    continuation.resume(returning: (data, response))
                } else {
                    continuation.resume(throwing: NSError(domain: "Unknown Error", code: -1, userInfo: nil))
                }
            }
            task.resume()
        }
    }
}
