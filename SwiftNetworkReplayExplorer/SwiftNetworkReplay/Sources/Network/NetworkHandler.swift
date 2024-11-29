//
//  StrategyHandler.swift
//  RSSParserTests
//
//  Created by Ivan Borinschi on 21.11.2024.
//

import Foundation

public enum NetworkHandlerError: Error {
    
    case missingStrategy
    
    var localizedDescription: String {
        switch self {
        case .missingStrategy:
            return "Missing strategy"
        }
    }
}

public final class NetworkHandler: URLProtocol {
    
    static var currentStrategy: NetworkHandlerStrategy?

    // MARK: - URLProtocol Overrides

    public override class func canInit(with request: URLRequest) -> Bool {
        guard let currentStrategy = Self.currentStrategy else {
            return false
        }
        return currentStrategy.shouldHandle(request: request)
    }

    public override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        FrameworkLogger.log("Canonicalizing request", info: ["URL": request.url?.absoluteString ?? "Unknown URL"])
        return request
    }
    
    public override func startLoading() {
        guard let currentStrategy = Self.currentStrategy else {
            client?.urlProtocol(self, didFailWithError: FrameworkLogger.logAndReturn(
                error: NetworkHandlerError.missingStrategy
            ))
            return
        }
        
        Task {
            do {
                let result = try await currentStrategy.handle(request: request)
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
