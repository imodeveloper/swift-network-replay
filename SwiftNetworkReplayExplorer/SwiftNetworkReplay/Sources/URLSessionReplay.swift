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
    
    var responseResolver: HTTPURLDataTaskProcessor = DefaultHTTPURLDataTaskProcessor()
    var fileManager: FileManagerProtocol = DefaultFileManager()
    var recordingDirectory: RecordingDirectoryPathResolver = DefaultRecordingDirectoryPathResolver()
    var fileNameResolver: FileNameResolver = DefaultFileNameResolver()
    
    private let logger = OSLog(
        subsystem: Bundle.main.bundleIdentifier ?? "SwiftNetworkReplay", category: "SessionReplay"
    )
    
    public func doesRecordingExistsFor(request: URLRequest) -> Bool {
        let fileURL = getFileUrl(request: request)
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    public func isSessionReady() -> Bool {
        if recordingDirectory.getRecordingDirectoryPath().isEmpty {
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
            try recordingDirectory.createRecordingDirectoryIfNeed()
        } catch {
            throw error
        }

        // Update the request with a custom header.
        var newRequest = request
        newRequest.setValue("true", forHTTPHeaderField: "X-SwiftNetworkReplay")
        
        // Execute the request using async/await.
        let (data, response) = try await session.asyncData(for: newRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Invalid Response", code: -1, userInfo: nil)
        }
        
        // Process and record the response.
        let recordedResponseData = try responseResolver.encodeDataTaskResult(
            newRequest: newRequest,
            data: data,
            httpResponse: httpResponse
        )
        
        let fileUrl = getFileUrl(request: request)
        try recordedResponseData.write(to: fileUrl, options: .atomic)
        
        os_log(
            "Successfully recorded response for URL: %{public}@",
            log: logger,
            type: .info,
            request.url?.absoluteString ?? "Unknown URL"
        )
        
        // Replay the response and return the result.
        return try await replayResponse(data: recordedResponseData, url: request.url!)
    }
    
    /// Replays the recorded response.
    /// - Parameters:
    ///   - data: The recorded response data.
    ///   - url: The URL for the recorded response.
    /// - Returns: A tuple containing the HTTP URL response and the response data.
    /// - Throws: An error if decoding the recorded data fails.
    func replayResponse(data: Data, url: URL) async throws -> (httpURLResponse: HTTPURLResponse, responseData: Data) {
        guard let result = try? responseResolver.decodeDataTaskResult(data: data) else {
            os_log(
                "Failed to parse recorded data for URL: %{public}@",
                log: logger,
                type: .error,
                url.absoluteString
            )
            
            throw NSError(domain: "Invalid Recorded Data", code: -2, userInfo: nil)
        }
        
        let response = HTTPURLResponse(
            url: url,
            statusCode: result.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: result.responseHeaders
        )!
        
        return (httpURLResponse: response, responseData: result.responseData)
    }
    
    func replayRecordResponse(fileURL: URL, url: URL) async throws -> (httpURLResponse: HTTPURLResponse, responseData: Data) {
        let recordedData = try Data(contentsOf: fileURL)
        return try await replayResponse(data: recordedData, url: url)
    }
    
    public func replayRecordFor(request: URLRequest) async throws -> (httpURLResponse: HTTPURLResponse, responseData: Data) {
        
        guard let url = request.url else {
            os_log(
                "Failed: Invalid URL in request",
                log: logger,
                type: .error
            )
            throw NSError(domain: "Invalid URL", code: -1, userInfo: nil)
        }
        
        let fileUrl = getFileUrl(request: request)
        return try await replayRecordResponse(fileURL: fileUrl, url: url)
    }
    
    public func getFileUrl(request: URLRequest) -> URL {
        let fileName = fileNameResolver.resolveFileName(
            for: request,
            testName: recordingDirectory.getRecordingFolderName()
        )
        return URL(
            fileURLWithPath: recordingDirectory.getRecordingDirectoryPath()
        ).appendingPathComponent(fileName)
    }
    
    public func removeRecordingSessionFolder() throws {
        try recordingDirectory.removeRecordingDirectory()
    }
    
    public func setSession(dirrectoryPath: String, sessionFolderName: String) {
        recordingDirectory.setTestDetails(
            filePath: dirrectoryPath,
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
