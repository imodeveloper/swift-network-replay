//
//  RequestHandlingStrategy.swift
//  SwiftNetworkReplayExplorer
//
//  Created by Ivan Borinschi on 03.12.2024.
//

public enum RequestHandlingStrategyError: Error, LocalizedError {
    case noRequestsToExecute
    public var errorDescription: String? {
        switch self {
        case .noRequestsToExecute:
            return "No requests to execute"
        }
    }
}

public protocol RequestHandlingStrategy {
    func handle(request: URLRequest) async throws -> NetworkStrategyResponse
}


extension Array: RequestHandlingStrategy where Element == RequestHandlingStrategy {
    public func handle(request: URLRequest) async throws -> NetworkStrategyResponse {
        for task in self {
            return try await task.handle(request: request)
        }
        throw RequestHandlingStrategyError.noRequestsToExecute
    }
}
