//
//  ReplayData.swift
//  SwiftNetworkReplayExplorer
//
//  Created by Ivan Borinschi on 29.11.2024.
//

public struct ReplayData {
    let url: URL
    let httpURLResponse: HTTPURLResponse
    let responseData: Data
}

public protocol NetworkHandlerStrategy {
    func shouldHandle(request: URLRequest) -> Bool
    func handle(request: URLRequest) async throws -> ReplayData
}
