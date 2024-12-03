//
//  RequestRecordingAndReplayingStrategy.swift
//  SwiftNetworkReplayExplorer
//
//  Created by Ivan Borinschi on 29.11.2024.
//

public enum RequestRecordingAndReplayingStrategyError: Error, LocalizedError {
    
    case missingStrategy
    case invalidUrlInRequest(URLRequest)
    case sessionReplayNotConfigured(URLRequest)
    case noRecordFoundForRequest(URLRequest, URL)
    case failedToReplay(URL, Error)
    case failedToPerformLiveRequest(URL, Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidUrlInRequest(let request):
            return "Invalid URL in the request. Request: \(request.debugDescription)"
        case .sessionReplayNotConfigured:
            return "Session replay is not configured."
        case .noRecordFoundForRequest(let request, let fileUrl):
            return "No record was found for the request.\nRequest: \(request.debugDescription),\nRecording File URL: \(fileUrl.absoluteString)"
        case .failedToReplay(let url, let error):
            return "Failed to replay the\nURL: \(url.absoluteString).\nError: \(error.localizedDescription)"
        case .failedToPerformLiveRequest(let url, let error):
            return "Failed to perform live request for\nURL: \(url.absoluteString).\nError: \(error.localizedDescription)"
        case .missingStrategy:
            return "Missing strategy"
        }
    }
}

public final class RequestRecordingAndReplayingStrategy: RequestFilterStrategy, RequestHandlingStrategy {
    
    // MARK: - Start/Stop Replay

    @discardableResult static func start(
        dirrectoryPath: String = #file,
        sessionFolderName: String = #function,
        isRecordingEnabled: Bool = false
    ) -> RequestRecordingAndReplayingStrategy {
        let sessionReplay = DefaultURLSessionReplay()
        sessionReplay.setSession(dirrectoryPath: dirrectoryPath, sessionFolderName: sessionFolderName)
        let strategy = RequestRecordingAndReplayingStrategy(
            sessionReplay: sessionReplay,
            isRecordingEnabled: isRecordingEnabled
        )
        return strategy
    }
    
    private var sessionReplay: URLSessionReplay
    private var isRecordingEnabled: Bool = false
    
    
    public init(sessionReplay: URLSessionReplay, isRecordingEnabled: Bool) {
        self.sessionReplay = sessionReplay
        self.isRecordingEnabled = isRecordingEnabled
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
        
        FrameworkLogger.log("Intercepting request", info: ["URL": url.absoluteString])
        return true
    }
    
    public func handle(request: URLRequest) async throws -> NetworkStrategyResponse {
        guard let url = request.url else {
            throw FrameworkLogger.logAndReturn(error: RequestRecordingAndReplayingStrategyError.invalidUrlInRequest(request))
        }
        
        guard sessionReplay.isSessionReady() else {
            throw FrameworkLogger.logAndReturn(error: RequestRecordingAndReplayingStrategyError.sessionReplayNotConfigured(request))
        }
        
        FrameworkLogger.log("Start loading for URL", info: ["URL": url.absoluteString])
        
        var newRequest = request
        newRequest.setValue("true", forHTTPHeaderField: "X-SwiftNetworkReplay")
        
        if shouldReplay(newRequest: newRequest) {
            return try await replayRecordedRequest(newRequest: newRequest, url: url)
        } else if isRecordingEnabled {
            return try await recordAndPerformLiveRequest(newRequest: newRequest, url: url)
        } else {
            throw FrameworkLogger.logAndReturn(
                error: RequestRecordingAndReplayingStrategyError.noRecordFoundForRequest(newRequest, sessionReplay.getFileUrl(request: newRequest))
            )
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
    
    private func shouldReplay(newRequest: URLRequest) -> Bool {
        return sessionReplay.doesRecordingExistsFor(request: newRequest) && !isRecordingEnabled
    }

    private func replayRecordedRequest(newRequest: URLRequest, url: URL) async throws -> NetworkStrategyResponse {
        do {
            let result = try await sessionReplay.replayRecordFor(request: newRequest)
            return NetworkStrategyResponse(
                url: url,
                httpURLResponse: result.httpURLResponse,
                responseData: result.responseData
            )
        } catch {
            throw FrameworkLogger.logAndReturn(
                error: RequestRecordingAndReplayingStrategyError.failedToReplay(url, error)
            )
        }
    }

    private func recordAndPerformLiveRequest(newRequest: URLRequest, url: URL) async throws -> NetworkStrategyResponse {
        FrameworkLogger.log("Recording mode is active. Performing live request", info: ["URL": newRequest.url?.absoluteString ?? "missing url"])
        do {
            let result = try await sessionReplay.performRequestAndRecord(request: newRequest)
            return NetworkStrategyResponse(
                url: url,
                httpURLResponse: result.httpURLResponse,
                responseData: result.responseData
            )
        } catch {
            throw FrameworkLogger.logAndReturn(
                error: RequestRecordingAndReplayingStrategyError.failedToPerformLiveRequest(url, error)
            )
        }
    }
}
