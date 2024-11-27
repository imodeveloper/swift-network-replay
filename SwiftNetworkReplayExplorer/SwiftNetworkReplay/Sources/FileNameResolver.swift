//
//  FileNameResolver.swift
//  SwiftNetworkReplayExplorer
//
//  Created by Ivan Borinschi on 22.11.2024.
//

import CryptoKit
import Foundation

public protocol FileNameResolver {
    func resolveFileName(for request: URLRequest, testName: String) -> String
}

final class DefaultFileNameResolver: FileNameResolver {
    public func resolveFileName(for request: URLRequest, testName: String) -> String {
        
        let url = request.url
        var domain = url?.host ?? "unknown_domain"
        domain = domain.replacingOccurrences(of: "https:", with: "")
        domain = domain.replacingOccurrences(of: "http:", with: "")
        domain = domain.replacingOccurrences(of: "www", with: "")
        domain = domain.replacingOccurrences(of: "//", with: "")
        domain = domain.replacingOccurrences(of: ":", with: "")
        domain = domain.replacingOccurrences(of: "/", with: "_")

        let headersString = request.allHTTPHeaderFields?
            .sorted { $0.key < $1.key } // Sort headers by key
            .map { "\($0.key):\($0.value)" }
            .joined(separator: "&") ?? ""

        let bodyString = request.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        let pathHash = sha256Hash(for: "\(testName)\(headersString)\(bodyString)\(url?.absoluteString ?? "missing_url")")

        return "\(request.httpMethod ?? "UNKNOWN")_\(domain)_\(pathHash).json"
    }

    private func sha256Hash(for input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.prefix(8).compactMap { String(format: "%02x", $0) }.joined()
    }
}
