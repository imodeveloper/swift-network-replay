//
//  ResponseModificationStrategy.swift
//  SwiftNetworkReplayExplorer
//
//  Created by Ivan Borinschi on 03.12.2024.
//


public protocol ResponseModificationStrategy {
    func modify(response: NetworkStrategyResponse) async throws -> NetworkStrategyResponse
}

extension Array: ResponseModificationStrategy where Element == ResponseModificationStrategy {
    public func modify(response: NetworkStrategyResponse) async throws -> NetworkStrategyResponse {
        var processedResponse = response
        for task in self {
            processedResponse = try await task.modify(response: processedResponse)
        }
        return processedResponse
    }
}
