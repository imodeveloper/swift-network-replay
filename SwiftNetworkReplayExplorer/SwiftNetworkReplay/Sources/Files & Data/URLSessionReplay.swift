//
//  URLSessionReplay.swift
//  SwiftNetworkReplay
//
//  Created by Ivan Borinschi on 22.11.2024.
//

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

public enum URLSessionReplayError: Error {
    case invalidResponse(URLRequest)
    case invalidRecordedData(URLRequest)
    case unknownError
    case directoryCreationFailed(Error)
    case directoryRemovalFailed(Error)
    
    var localizedDescription: String {
        switch self {
        case .invalidResponse(let request):
            return "Invalid response for request: \(request.debugDescription)"
        case .invalidRecordedData(let request):
            return "Invalid recorded data for request: \(request.debugDescription)"
        case .unknownError:
            return "An unknown error occurred."
        case .directoryCreationFailed(let error):
            return "Failed to create directory. Error: \(error.localizedDescription)"
        case .directoryRemovalFailed(let error):
            return "Failed to remove directory. Error: \(error.localizedDescription)"
        }
    }
}

public final class DefaultURLSessionReplay: URLSessionReplay {
    
    private var session: URLSession = .shared
    
    var dataTaskSerializer: HTTPDataTaskSerializer = DefaultHTTPDataTaskSerializer()
    var fileManager: FileManagerProtocol = DefaultFileManager()
    var recordingDirectoryManager: DirectoryManager = DefaultDirectoryManager()
    var fileNameResolver: RequestFileNameGenerator = DefaultRequestFileNameGenerator()
        
    public func doesRecordingExistsFor(request: URLRequest) -> Bool {
        let fileURL = getFileUrl(request: request)
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    public func isSessionReady() -> Bool {
        if recordingDirectoryManager.directoryPath.isEmpty {
            FrameworkLogger.log("Error: recordingDirectoryPath is not set.", type: .error)
            return false
        }
        return true
    }
    
    public func performRequestAndRecord(request: URLRequest) async throws -> (httpURLResponse: HTTPURLResponse, responseData: Data) {
        do {
            try recordingDirectoryManager.createDirectoryIfNeeded()
        } catch {
            throw FrameworkLogger.logAndReturn(
                error: URLSessionReplayError.directoryCreationFailed(error)
            )
        }

        var newRequest = request
        newRequest.setValue("true", forHTTPHeaderField: "X-SwiftNetworkReplay")
        
        let (responseData, httpResponse) = try await session.asyncData(for: newRequest)

        guard let httpResponse = httpResponse as? HTTPURLResponse else {
            throw FrameworkLogger.logAndReturn(
                error: URLSessionReplayError.invalidResponse(newRequest)
            )
        }
        
        let recordedResponseData = try dataTaskSerializer.encode(
            request: newRequest,
            responseData: responseData,
            httpResponse: httpResponse
        )
        
        let fileUrl = getFileUrl(request: newRequest)
        try recordedResponseData.write(to: fileUrl, options: .atomic)
        
        FrameworkLogger.log(
            "Successfully recorded response for URL",
            info: ["URL": request.url?.absoluteString ?? "Unknown URL", "File Path": fileUrl.absoluteString]
        )
        
        return try await replayRecordFor(request: newRequest)
    }
    
    public func replayRecordFor(request: URLRequest) async throws -> (httpURLResponse: HTTPURLResponse, responseData: Data) {
        let recordedData = try Data(contentsOf: getFileUrl(request: request))
        
        guard let result = try? dataTaskSerializer.decode(request: request, data: recordedData) else {
            FrameworkLogger.log(
                "Failed to parse recorded data",
                type: .error,
                info: ["URL": request.url?.absoluteString ?? "Missing URL"]
            )
            throw FrameworkLogger.logAndReturn(
                error: URLSessionReplayError.invalidRecordedData(request)
            )
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
        do {
            try recordingDirectoryManager.removeDirectoryIfExists()
        } catch {
            throw FrameworkLogger.logAndReturn(
                error: URLSessionReplayError.directoryRemovalFailed(error)
            )
        }
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
                    continuation.resume(
                        throwing: FrameworkLogger.logAndReturn(
                            error: URLSessionReplayError.unknownError
                        )
                    )
                }
            }
            task.resume()
        }
    }
}

