//
//  ReplaceOcurrenceModifier.swift
//  SwiftNetworkReplayExplorer
//
//  Created by Ivan Borinschi on 03.12.2024.
//


final class ReplaceOcurrenceModifierStrategy: ResponseModificationStrategy {
    func modify(response: NetworkStrategyResponse) async throws -> NetworkStrategyResponse {
        return response
    }
}
