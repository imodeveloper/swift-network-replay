//
//  SwiftNetworkReplayError.swift
//  SwiftNetworkReplayExplorer
//
//  Created by Ivan Borinschi on 29.11.2024.
//


public enum SwiftNetworkReplayError: Error {
    case invalidURL
    case invalidResponse
    case directoryCreationFailed(String)
    case directoryRemovalFailed(String)
    case recordingNotFound
    case decodingFailed
    case unknown(String)
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "The URL provided is invalid."
        case .invalidResponse:
            return "The response received is invalid."
        case .directoryCreationFailed(let path):
            return "Failed to create directory at path: \(path)."
        case .directoryRemovalFailed(let path):
            return "Failed to remove directory at path: \(path)."
        case .recordingNotFound:
            return "No recording was found for the request."
        case .decodingFailed:
            return "Failed to decode the recorded data."
        case .unknown(let message):
            return "An unknown error occurred: \(message)"
        }
    }
}
