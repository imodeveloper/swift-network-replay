//
//  NetworkStrategyResponse.swift
//  SwiftNetworkReplayExplorer
//
//  Created by Ivan Borinschi on 03.12.2024.
//


public struct NetworkStrategyResponse {
    let url: URL
    let httpURLResponse: HTTPURLResponse
    let responseData: Data
}
