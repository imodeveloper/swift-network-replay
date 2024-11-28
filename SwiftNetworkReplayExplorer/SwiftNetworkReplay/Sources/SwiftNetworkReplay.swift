//
//  SwiftNetworkReplay.swift
//  RSSParserTests
//
//  Created by Ivan Borinschi on 21.11.2024.
//

import Foundation
import os.log

public final class SwiftNetworkReplay: URLProtocol {
    
    private static var isRecording: Bool = false
    static var sessionReplay: URLSessionReplay = DefaultURLSessionReplay()
    private static var replayUrlsWithKeywords: [String] = []
    
    private static let logger = OSLog(
        subsystem: Bundle.main.bundleIdentifier ?? "SwiftNetworkReplay", category: "Networking"
    )

    public override class func canInit(with request: URLRequest) -> Bool {
        if request.value(forHTTPHeaderField: "X-SwiftNetworkReplay") != nil {
            return false
        }
        
        guard let url = request.url else { return false }
        let isHttpRequest = url.scheme == "http" || url.scheme == "https"
        
        if isHttpRequest {
            if !replayUrlsWithKeywords.isEmpty {
                // Check if the request URL contains any of the specified keywords
                let urlString = url.absoluteString
                let containsKeyword = replayUrlsWithKeywords.contains { keyword in
                    urlString.contains(keyword)
                }
                
                if !containsKeyword {
                    return false
                }
            }
            os_log(
                "Intercepting request: %{public}@",
                log: logger,
                type: .info, url.absoluteString
            )
        }
        return isHttpRequest
    }

    public override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        os_log(
            "Canonicalizing request: %{public}@",
            log: logger,
            type: .info,
            request.url?.absoluteString ?? "Unknown URL"
        )
        return request
    }
    
    public override func startLoading() {
        guard let url = request.url else {
            os_log(
                "Failed: Invalid URL in request",
                log: Self.logger,
                type: .error
            )
            let error = NSError(domain: "Invalid URL", code: -1, userInfo: nil)
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        
        guard Self.sessionReplay.isSessionReady() else {
            let error = NSError(domain: "Session replay is not configured", code: -1, userInfo: nil)
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        
        os_log(
            "Start loading for URL: %{public}@",
            log: Self.logger,
            type: .info,
            url.absoluteString
        )
        
        var newRequest = request
        newRequest.setValue("true", forHTTPHeaderField: "X-SwiftNetworkReplay")
        
        if Self.sessionReplay.doesRecordingExistsFor(request: newRequest) && !Self.isRecording {
            Task {
                do {
                    let result = try await Self.sessionReplay.replayRecordFor(request: newRequest)
                    replay(url: url, httpURLResponse: result.httpURLResponse, responseData: result.responseData)
                } catch {
                    os_log(
                        "Failed to replay URL: %{public}@. Error: %{public}@",
                        log: Self.logger,
                        type: .error,
                        url.absoluteString,
                        error.localizedDescription
                    )
                    client?.urlProtocol(self, didFailWithError: error)
                }
            }
            
        } else if Self.isRecording {
            
            os_log(
                "Recording mode is active. Performing live request for URL: %{public}@",
                log: Self.logger,
                type: .info,
                request.url?.absoluteString ?? "missing url"
            )
            
            Task {
                do {
                    let result = try await Self.sessionReplay.performRequestAndRecord(request: request)
                    replay(url: url, httpURLResponse: result.httpURLResponse, responseData: result.responseData)
                } catch {
                    os_log(
                        "Failed Performing live request for URL: %{public}@",
                        log: Self.logger,
                        type: .error,
                        error.localizedDescription
                    )
                }
            }
            
        } else {
            os_log(
                "No record was found for: %{public}@ %{public}@",
                log: Self.logger,
                type: .error,
                url.absoluteString,
                Self.sessionReplay.getFileUrl(request: request).absoluteString
            )
            let error = NSError(domain: "No record was found", code: -2, userInfo: nil)
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    
    public override func stopLoading() {
        os_log(
            "Stopped loading for URL: %{public}@",
            log: Self.logger,
            type: .info,
            request.url?.absoluteString ?? "Unknown URL"
        )
    }
    
    private func replay(
        url: URL,
        httpURLResponse: HTTPURLResponse,
        responseData: Data
    )  {
        client?.urlProtocol(self, didReceive: httpURLResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: responseData)
        client?.urlProtocolDidFinishLoading(self)
        os_log(
            "Did replay data for URL: %{public}@",
            log: Self.logger,
            type: .info,
            url.absoluteString
        )
    }
    
    public static func start(
        dirrectoryPath: String = #file,
        sessionFolderName: String = #function,
        record: Bool = false,
        replayUrlsWithKeywords: [String] = []
    ) {
        URLProtocol.registerClass(SwiftNetworkReplay.self)
        Self.sessionReplay.setSession(dirrectoryPath: dirrectoryPath, sessionFolderName: sessionFolderName)
        Self.isRecording = record
        Self.replayUrlsWithKeywords = replayUrlsWithKeywords
    }
    
    public static func stop() {
        URLProtocol.unregisterClass(SwiftNetworkReplay.self)
    }
    
    public static func removeRecordingDirectory() throws {
        try Self.sessionReplay.removeRecordingSessionFolder()
    }
}
