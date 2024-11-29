//
//  SwiftNetworkReplay.swift
//  RSSParserTests
//
//  Created by Ivan Borinschi on 21.11.2024.
//

import Foundation

public enum SwiftNetworkReplayError: Error {
    case invalidUrlInRequest(URLRequest)
    case sessionReplayNotConfigured(URLRequest)
    case noRecordFoundForRequest(URLRequest, URL)
    case failedToReplay(URL, Error)
    case failedToPerformLiveRequest(URL, Error)
    
    var localizedDescription: String {
        switch self {
        case .invalidUrlInRequest(let request):
            return "Invalid URL in the request. Request: \(request.debugDescription)"
        case .sessionReplayNotConfigured:
            return "Session replay is not configured."
        case .noRecordFoundForRequest(let request, let fileUrl):
            return "No record was found for the request. Request: \(request.debugDescription), Recording File URL: \(fileUrl.absoluteString)"
        case .failedToReplay(let url, let error):
            return "Failed to replay the URL: \(url.absoluteString). Error: \(error.localizedDescription)"
        case .failedToPerformLiveRequest(let url, let error):
            return "Failed to perform live request for URL: \(url.absoluteString). Error: \(error.localizedDescription)"
        }
    }
}

public final class SwiftNetworkReplay: URLProtocol {
    
    private static var isRecordingEnabled: Bool = false
    private static var urlKeywordsForReplay: [String] = []
    static var sessionReplay: URLSessionReplay = DefaultURLSessionReplay()

    // MARK: - URLProtocol Overrides

    public override class func canInit(with request: URLRequest) -> Bool {
        if hasReplayHeader(in: request) {
            return false
        }
        
        guard let url = request.url, isHttpRequest(url: url) else {
            return false
        }
        
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
            client?.urlProtocol(
                self,
                didFailWithError: FrameworkLogger.logAndReturn(
                    error: SwiftNetworkReplayError.invalidUrlInRequest(request)
                )
            )
            return
        }
        
        guard Self.sessionReplay.isSessionReady() else {
            client?.urlProtocol(
                self,
                didFailWithError: FrameworkLogger.logAndReturn(
                    error: SwiftNetworkReplayError.sessionReplayNotConfigured(request)
                )
            )
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
                    client?.urlProtocol(
                        self,
                        didFailWithError: FrameworkLogger.logAndReturn(
                            error: SwiftNetworkReplayError.failedToReplay(url, error)
                        )
                    )
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
                    client?.urlProtocol(
                        self,
                        didFailWithError: FrameworkLogger.logAndReturn(
                            error: SwiftNetworkReplayError.failedToPerformLiveRequest(url, error)
                        )
                    )
                }
            }
        } else {
            client?.urlProtocol(
                self,
                didFailWithError: FrameworkLogger.logAndReturn(
                    error: SwiftNetworkReplayError.noRecordFoundForRequest(request, Self.sessionReplay.getFileUrl(request: request))
                )
            )
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
    ) {
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
