//
//  RecordingURLProtocol.swift
//  RSSParserTests
//
//  Created by Ivan Borinschi on 21.11.2024.
//

import Foundation
import os.log

final class SwiftNetworkReplay: URLProtocol {
    
    private static var fileManager: FileManager = .default
    private static var session: URLSession = .shared
    private static var record: Bool = false
    
    static var fileNameResolver: FileNameResolver = DefaultFileNameResolver()
    static var recordingDirectory: RecordingDirectoryPathResolver = DefaultRecordingDirectoryPathResolver()
    
    private static let logger = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "SwiftNetworkReplay", category: "Networking")

    override class func canInit(with request: URLRequest) -> Bool {
        if request.value(forHTTPHeaderField: "X-RecordingURLProtocol") != nil {
            return false
        }
        
        let isHttpRequest = request.url?.scheme == "http" || request.url?.scheme == "https"
        if isHttpRequest {
            os_log("Intercepting request: %{public}@", log: logger, type: .info, request.url?.absoluteString ?? "Unknown URL")
        }
        return isHttpRequest
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        os_log("Canonicalizing request: %{public}@", log: logger, type: .info, request.url?.absoluteString ?? "Unknown URL")
        return request
    }
    
    override func startLoading() {
        guard let url = request.url else {
            os_log("Failed: Invalid URL in request", log: Self.logger, type: .error)
            let error = NSError(domain: "Invalid URL", code: -1, userInfo: nil)
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        
        if Self.recordingDirectory.getRecordingDirectoryPath().isEmpty {
            os_log("Error: recordingDirectoryPath is not set.", log: Self.logger, type: .error)
            let error = NSError(domain: "Recording Directory Path Not Set", code: -1, userInfo: nil)
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        
        os_log("Start loading for URL: %{public}@", log: Self.logger, type: .info, url.absoluteString)
        
        
        let fileName = Self.generateFileName(for: request)
        let fileURL = URL(fileURLWithPath: Self.recordingDirectory.getRecordingDirectoryPath()).appendingPathComponent(fileName)
        
        if Self.fileManager.fileExists(atPath: fileURL.path) && !Self.record {
            do {
                let recordedData = try Data(contentsOf: fileURL)
                os_log("Replaying recorded response for URL: %{public}@", log: Self.logger, type: .info, url.absoluteString)
                replayResponse(data: recordedData, url: url)
            } catch {
                os_log("Failed to load recorded data for URL: %{public}@. Error: %{public}@", log: Self.logger, type: .error, url.absoluteString, error.localizedDescription)
                client?.urlProtocol(self, didFailWithError: error)
            }
        } else if Self.record {
            if !Self.fileManager.fileExists(atPath: Self.recordingDirectory.getRecordingDirectoryPath()) {
                do {
                    try Self.createRecordingDirectory()
                } catch {
                    os_log("Failed to create directory at path: %{public}@. Error: %{public}@", log: Self.logger, type: .error, Self.recordingDirectory.getRecordingDirectoryPath(), error.localizedDescription)
                    let error = NSError(domain: "Directory Creation Failed", code: -1, userInfo: nil)
                    client?.urlProtocol(self, didFailWithError: error)
                    return
                }
            }
            
            os_log("Recording mode is active. Performing live request for URL: %{public}@", log: Self.logger, type: .info, url.absoluteString)
            performRequestAndRecord(fileURL: fileURL)
        } else {
            os_log("No record was found for: %{public}@ %{public}@", log: Self.logger, type: .error, url.absoluteString, fileURL.path)
            let error = NSError(domain: "No record was found", code: -2, userInfo: nil)
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    
    static func createRecordingDirectory() throws {
        try Self.fileManager.createDirectory(
            atPath: Self.recordingDirectory.getRecordingDirectoryPath(),
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
    
    static func removeRecordingDirectory() throws {
        let directoryPath = Self.recordingDirectory.getRecordingDirectoryPath()
        if Self.fileManager.fileExists(atPath: directoryPath) {
            do {
                try Self.fileManager.removeItem(atPath: directoryPath)
                os_log("Successfully removed recording directory at path: %{public}@", log: Self.logger, type: .info, directoryPath)
            } catch {
                os_log("Failed to remove recording directory at path: %{public}@. Error: %{public}@", log: Self.logger, type: .error, directoryPath, error.localizedDescription)
                throw error
            }
        } else {
            os_log("No recording directory exists at path: %{public}@", log: Self.logger, type: .info, directoryPath)
        }
    }

    override func stopLoading() {
        os_log("Stopped loading for URL: %{public}@", log: Self.logger, type: .info, request.url?.absoluteString ?? "Unknown URL")
    }
    
    private func replayResponse(data: Data, url: URL) {
        guard let responseObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let responseDataString = responseObject["responseData"] as? String, let responseData = responseDataString.data(using: .utf8),
              let responseHeaders = responseObject["responseHeaders"] as? [String: String],
              let statusCode = responseObject["statusCode"] as? Int else {
            os_log("Failed to parse recorded data for URL: %{public}@", log: Self.logger, type: .error, url.absoluteString)
            let error = NSError(domain: "Invalid Recorded Data", code: -2, userInfo: nil)
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        
        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: responseHeaders
        )!
        
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: responseData)
        client?.urlProtocolDidFinishLoading(self)
        os_log("Did replay data for URL: %{public}@", log: Self.logger, type: .info, url.absoluteString)
    }

    private func performRequestAndRecord(fileURL: URL) {
        var newRequest = request
        newRequest.setValue("true", forHTTPHeaderField: "X-RecordingURLProtocol")
        
        let task = Self.session.dataTask(with: newRequest) { [weak self] data, response, error in
            guard let self = self else { return }
            if let data = data, let httpResponse = response as? HTTPURLResponse {
                do {
                    let filteredResponseHeaders = httpResponse.allHeaderFields.filter { key, _ in
                        guard let keyString = key as? String else { return false }
                        return !keyString.lowercased().contains("date")
                    }
                    let filteredRequestHeaders = newRequest.allHTTPHeaderFields?.filter { key, _ in
                        !key.lowercased().contains("date")
                    }
                    let requestBodyString = newRequest.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                    var responseObject: [String: Any] = [
                        "service": newRequest.url?.host ?? "unknown_service",
                        "requestType": newRequest.httpMethod ?? "GET",
                        "requestHeaders": filteredRequestHeaders ?? [:],
                        "requestBody": requestBodyString,
                        "responseHeaders": filteredResponseHeaders,
                        "statusCode": httpResponse.statusCode,
                    ]
                    responseObject["responseData"] = String(data: data, encoding: .utf8) ?? ""
                    
                    let sortedResponseObject = responseObject.sorted { $0.key < $1.key }
                    let recordedResponseData = try JSONSerialization.data(withJSONObject: Dictionary(uniqueKeysWithValues: sortedResponseObject), options: .prettyPrinted)
                    try recordedResponseData.write(to: fileURL, options: .atomic)
                    os_log("Successfully recorded response for URL: %{public}@", log: Self.logger, type: .info, self.request.url?.absoluteString ?? "Unknown URL")
                    self.replayResponse(data: recordedResponseData, url: self.request.url!)
                } catch {
                    os_log("Error saving recorded response: %{public}@", log: Self.logger, type: .error, error.localizedDescription)
                    self.client?.urlProtocol(self, didFailWithError: error)
                }
            } else if let error = error {
                os_log("Request failed for URL: %{public}@ with error: %{public}@", log: Self.logger, type: .error, self.request.url?.absoluteString ?? "Unknown URL", error.localizedDescription)
                self.client?.urlProtocol(self, didFailWithError: error)
            }
        }
        task.resume()
    }

    static func replay(filePath: String = #file, test: String = #function, record: Bool = false) {
        URLProtocol.registerClass(SwiftNetworkReplay.self)
        recordingDirectory.setTestDetails(filePath: filePath, folderName: test)
        Self.record = record
        os_log("Recording directory path set to: %{public}@", log: Self.logger, type: .info, Self.recordingDirectory.getRecordingDirectoryPath())
    }

    private static func generateFileName(for urlRequest: URLRequest) -> String {
        return fileNameResolver.resolveFileName(
            for: urlRequest,
            testName: Self.recordingDirectory.getRecordingFolderName()
        )
    }
}
