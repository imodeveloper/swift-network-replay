//
//  RecordReplayStrategy.swift
//  SwiftNetworkReplayExplorer
//
//  Created by Ivan Borinschi on 29.11.2024.
//

public enum RecordReplayStrategyError: Error {
    
    case missingStrategy
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
        case .missingStrategy:
            return "Missing strategy"
        }
    }
}

public final class RecordReplayStrategy: SwiftNetworkStrategy {
    
    // MARK: - Start/Stop Replay

    @discardableResult public static func start(
        dirrectoryPath: String = #file,
        sessionFolderName: String = #function,
        isRecordingEnabled: Bool = false,
        urlKeywordsForReplay: [String] = []
    ) -> RecordReplayStrategy {
        URLProtocol.registerClass(SwiftNetworkReplayProtocol.self)
        let sessionReplay = DefaultURLSessionReplay()
        sessionReplay.setSession(dirrectoryPath: dirrectoryPath, sessionFolderName: sessionFolderName)
        let strategy = RecordReplayStrategy(
            sessionReplay: sessionReplay,
            isRecordingEnabled: isRecordingEnabled,
            urlKeywordsForReplay: urlKeywordsForReplay
        )
        SwiftNetworkReplayProtocol.currentStrategy = strategy
        return strategy
    }
    
    public static func stop() {
        URLProtocol.unregisterClass(SwiftNetworkReplayProtocol.self)
    }
    
    private var sessionReplay: URLSessionReplay
    private var isRecordingEnabled: Bool = false
    private var urlKeywordsForReplay: [String] = []
    
    public init(sessionReplay: URLSessionReplay, isRecordingEnabled: Bool, urlKeywordsForReplay: [String]) {
        self.sessionReplay = sessionReplay
        self.isRecordingEnabled = isRecordingEnabled
        self.urlKeywordsForReplay = urlKeywordsForReplay
    }
    
    public func removeRecordingSessionFolder() throws {
        try self.sessionReplay.removeRecordingSessionFolder()
    }
    
    public func shouldHandle(request: URLRequest) -> Bool {
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
    
    public func handle(request: URLRequest) async throws -> ReplayData {
        guard let url = request.url else {
            throw FrameworkLogger.logAndReturn(error: RecordReplayStrategyError.invalidUrlInRequest(request))
        }
        
        guard sessionReplay.isSessionReady() else {
            throw SwiftNetworkStrategyError.sessionReplayNotConfigured(request)
        }
        
        FrameworkLogger.log("Start loading for URL", info: ["URL": url.absoluteString])
        
        var newRequest = request
        newRequest.setValue("true", forHTTPHeaderField: "X-SwiftNetworkReplay")
        
        if shouldReplay(newRequest: newRequest) {
            return try await replayRecordedRequest(newRequest: newRequest, url: url)
        } else if isRecordingEnabled {
            return try await recordAndPerformLiveRequest(newRequest: newRequest, url: url)
        } else {
            throw RecordReplayStrategyError.noRecordFoundForRequest(newRequest, sessionReplay.getFileUrl(request: newRequest))
        }
    }
    
    // MARK: - Helper Methods

    private func hasReplayHeader(in request: URLRequest) -> Bool {
        return request.value(forHTTPHeaderField: "X-SwiftNetworkReplay") != nil
    }

    private func isHttpRequest(url: URL) -> Bool {
        guard let scheme = url.scheme else { return false }
        return scheme == "http" || scheme == "https"
    }

    private func containsReplayKeyword(in url: URL) -> Bool {
        let urlString = url.absoluteString
        return urlKeywordsForReplay.contains { keyword in
            urlString.contains(keyword)
        }
    }
    
    private func shouldReplay(newRequest: URLRequest) -> Bool {
        return sessionReplay.doesRecordingExistsFor(request: newRequest) && !isRecordingEnabled
    }

    private func replayRecordedRequest(newRequest: URLRequest, url: URL) async throws -> ReplayData {
        do {
            let result = try await sessionReplay.replayRecordFor(request: newRequest)
            return ReplayData(
                url: url,
                httpURLResponse: result.httpURLResponse,
                responseData: result.responseData
            )
        } catch {
            throw RecordReplayStrategyError.failedToReplay(url, error)
        }
    }

    private func recordAndPerformLiveRequest(newRequest: URLRequest, url: URL) async throws -> ReplayData {
        FrameworkLogger.log("Recording mode is active. Performing live request", info: ["URL": newRequest.url?.absoluteString ?? "missing url"])
        do {
            let result = try await sessionReplay.performRequestAndRecord(request: newRequest)
            return ReplayData(
                url: url,
                httpURLResponse: result.httpURLResponse,
                responseData: result.responseData
            )
        } catch {
            throw RecordReplayStrategyError.failedToPerformLiveRequest(url, error)
        }
    }
}
