//
//  StrategyHandler.swift
//  RSSParserTests
//
//  Created by Ivan Borinschi on 21.11.2024.
//

import Foundation

public enum NetworkReplayError: Error, LocalizedError {
    case noRequestsToExecute
    public var errorDescription: String? {
        switch self {
        case .noRequestsToExecute:
            return "No request to execute"
        }
    }
}

public final class NetworkReplay: URLProtocol {
    
    static var filter: [RequestFilterStrategy] = []
    static var request: [RequestHandlingStrategy] = []
    static var modify: [ResponseModificationStrategy] = []

    // MARK: - URLProtocol Overrides

    public override class func canInit(with request: URLRequest) -> Bool {
        return filter.shouldHandle(request: request)
    }

    public override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        FrameworkLogger.log("Canonicalizing request", info: ["URL": request.url?.absoluteString ?? "Unknown URL"])
        return request
    }

    public override func startLoading() {
        guard !Self.request.isEmpty else {
            client?.urlProtocol(self, didFailWithError: FrameworkLogger.logAndReturn(
                error: NetworkReplayError.noRequestsToExecute
            ))
            return
        }
        
        Task {
            do {
                let result = try await Self.request.handle(request: request)
                client?.urlProtocol(self, didReceive: result.httpURLResponse, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: result.responseData)
                client?.urlProtocolDidFinishLoading(self)
                FrameworkLogger.log("Replayed data", info: ["URL": result.url.absoluteString])
            } catch {
                client?.urlProtocol(self, didFailWithError: FrameworkLogger.logAndReturn(error: error))
            }
        }
    }

    public override func stopLoading() {
        FrameworkLogger.log(
            "Stopped loading for URL",
            info: ["URL": request.url?.absoluteString ?? "Unknown URL"]
        )
    }
}

extension NetworkReplay {
    
    public static func start(
        filter: [RequestFilterStrategy],
        request: [RequestHandlingStrategy],
        modify: [ResponseModificationStrategy] = [ResponseModificationStrategy]()
    ) {
        self.filter = filter
        self.request = request
        self.modify = modify
        URLProtocol.registerClass(NetworkReplay.self)
    }
    
    public static func stop() {
        URLProtocol.unregisterClass(NetworkReplay.self)
    }
    
    @discardableResult public static func recordAndReplay(
        dirrectoryPath: String = #file,
        sessionFolderName: String = #function,
        isRecordingEnabled: Bool = false,
        urlKeywordsForReplay: [String] = []
    ) -> RequestRecordingAndReplayingStrategy {
        
        let filter = KeywordFilterStrategy(
            urlKeywordsForReplay: urlKeywordsForReplay
        )
        
        let RequestRecordingAndReplayingStrategy = RequestRecordingAndReplayingStrategy.start(
            dirrectoryPath: dirrectoryPath,
            sessionFolderName: sessionFolderName,
            isRecordingEnabled: isRecordingEnabled
        )
        
        Self.start(
            filter: [filter, RequestRecordingAndReplayingStrategy],
            request: [RequestRecordingAndReplayingStrategy]
        )
        
        return RequestRecordingAndReplayingStrategy
    }
}
