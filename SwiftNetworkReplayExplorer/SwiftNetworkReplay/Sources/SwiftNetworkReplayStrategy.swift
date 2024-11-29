//
//  ReplayData.swift
//  SwiftNetworkReplayExplorer
//
//  Created by Ivan Borinschi on 29.11.2024.
//

public enum SwiftNetworkStrategyError: Error {
    
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

public struct ReplayData {
    let url: URL
    let httpURLResponse: HTTPURLResponse
    let responseData: Data
}

public protocol SwiftNetworkStrategy {
    func shouldHandle(request: URLRequest) -> Bool
    func handle(request: URLRequest) async throws -> ReplayData
}
