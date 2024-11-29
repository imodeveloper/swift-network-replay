//
//  SwiftNetworkReplay.swift
//  RSSParserTests
//
//  Created by Ivan Borinschi on 21.11.2024.
//

import Foundation

public final class SwiftNetworkReplay: URLProtocol {
    
    private static var isRecordingEnabled: Bool = false
    private static var urlKeywordsForReplay: [String] = []
    static var sessionReplay: URLSessionReplay = DefaultURLSessionReplay()

    // MARK: - URLProtocol Overrides

    public override class func canInit(with request: URLRequest) -> Bool {
        // Check if the request contains the replay-specific header
        if hasReplayHeader(in: request) {
            return false
        }
        
        // Validate the URL and its scheme
        guard let url = request.url, isHttpRequest(url: url) else {
            return false
        }
        
        // If keywords are provided, ensure the URL matches one of them
        if !urlKeywordsForReplay.isEmpty && !containsReplayKeyword(in: url) {
            return false
        }
        
        FrameworkLogger.log("Intercepting request", info: ["URL": url.absoluteString])
        return true
    }

    public override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        FrameworkLogger.log("Canonicalizing request", info: ["URL": request.url?.absoluteString ?? "Unknown URL"])
        return request
    }
    
    public override func startLoading() {
        guard let url = request.url else {
            FrameworkLogger.log("Failed: Invalid URL in request", type: .error)
            let error = NSError(domain: "Invalid URL", code: -1, userInfo: nil)
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        
        guard Self.sessionReplay.isSessionReady() else {
            let error = NSError(domain: "Session replay is not configured", code: -1, userInfo: nil)
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        
        FrameworkLogger.log("Start loading for URL", info: ["URL": url.absoluteString])
        
        var newRequest = request
        newRequest.setValue("true", forHTTPHeaderField: "X-SwiftNetworkReplay")
        
        if Self.sessionReplay.doesRecordingExistsFor(request: newRequest) && !Self.isRecordingEnabled {
            Task {
                do {
                    let result = try await Self.sessionReplay.replayRecordFor(request: newRequest)
                    replay(url: url, httpURLResponse: result.httpURLResponse, responseData: result.responseData)
                } catch {
                    FrameworkLogger.log(
                        "Failed to replay URL",
                        type: .error,
                        info: ["URL": url.absoluteString, "Error": error.localizedDescription]
                    )
                    client?.urlProtocol(self, didFailWithError: error)
                }
            }
        } else if Self.isRecordingEnabled {
            FrameworkLogger.log(
                "Recording mode is active. Performing live request",
                info: ["URL": request.url?.absoluteString ?? "missing url"]
            )
            
            Task {
                do {
                    let result = try await Self.sessionReplay.performRequestAndRecord(request: request)
                    replay(url: url, httpURLResponse: result.httpURLResponse, responseData: result.responseData)
                } catch {
                    FrameworkLogger.log(
                        "Failed performing live request",
                        type: .error,
                        info: ["URL": request.url?.absoluteString ?? "Unknown URL", "Error": error.localizedDescription]
                    )
                }
            }
        } else {
            FrameworkLogger.log(
                "No record was found for request",
                type: .error,
                info: [
                    "Request URL": url.absoluteString,
                    "Recording File URL": Self.sessionReplay.getFileUrl(request: request).absoluteString
                ]
            )
            let error = NSError(domain: "No record was found", code: -2, userInfo: nil)
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    
    public override func stopLoading() {
        FrameworkLogger.log(
            "Stopped loading for URL",
            info: ["URL": request.url?.absoluteString ?? "Unknown URL"]
        )
    }
    
    // MARK: - Replay Logic

    private func replay(
        url: URL,
        httpURLResponse: HTTPURLResponse,
        responseData: Data
    )  {
        client?.urlProtocol(self, didReceive: httpURLResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: responseData)
        client?.urlProtocolDidFinishLoading(self)
        FrameworkLogger.log("Replayed data", info: ["URL": url.absoluteString])
    }
    
    // MARK: - Start/Stop Replay

    public static func start(
        dirrectoryPath: String = #file,
        sessionFolderName: String = #function,
        isRecordingEnabled: Bool = false,
        urlKeywordsForReplay: [String] = []
    ) {
        URLProtocol.registerClass(SwiftNetworkReplay.self)
        Self.sessionReplay.setSession(dirrectoryPath: dirrectoryPath, sessionFolderName: sessionFolderName)
        Self.isRecordingEnabled = isRecordingEnabled
        Self.urlKeywordsForReplay = urlKeywordsForReplay
    }
    
    public static func stop() {
        URLProtocol.unregisterClass(SwiftNetworkReplay.self)
    }
    
    public static func removeRecordingDirectory() throws {
        try Self.sessionReplay.removeRecordingSessionFolder()
    }
    
    // MARK: - Helper Methods

    private class func hasReplayHeader(in request: URLRequest) -> Bool {
        return request.value(forHTTPHeaderField: "X-SwiftNetworkReplay") != nil
    }

    private class func isHttpRequest(url: URL) -> Bool {
        guard let scheme = url.scheme else { return false }
        return scheme == "http" || scheme == "https"
    }

    private class func containsReplayKeyword(in url: URL) -> Bool {
        let urlString = url.absoluteString
        return urlKeywordsForReplay.contains { keyword in
            urlString.contains(keyword)
        }
    }
}
