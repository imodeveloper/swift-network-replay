//
//  HTTPURLDataTaskProcessor.swift
//  SwiftNetworkReplay
//
//  Created by Ivan Borinschi on 22.11.2024.
//

import Foundation

public protocol HTTPURLDataTaskProcessor {
    func encodeDataTaskResult(newRequest: URLRequest, responseData: Data, httpResponse: HTTPURLResponse) throws -> Data
    func decodeDataTaskResult(request: URLRequest, data: Data) throws -> (httpURLResponse: HTTPURLResponse, responseData: Data)
}

public final class DefaultHTTPURLDataTaskProcessor: HTTPURLDataTaskProcessor {
    
    public func encodeDataTaskResult(newRequest: URLRequest, responseData: Data, httpResponse: HTTPURLResponse) throws -> Data {
        
        let filteredResponseHeaders = httpResponse.allHeaderFields.filter { key, _ in
            guard let keyString = key as? String else { return false }
            return !keyString.lowercased().contains("date")
        }
        
        let filteredRequestHeaders = newRequest.allHTTPHeaderFields?.filter { key, _ in
            !key.lowercased().contains("date")
        }
        
        let requestBodyString = newRequest.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        
        var responseObject: [String: Any] = [
            "service": newRequest.url?.host ?? "unknown_service",
            "requestType": newRequest.httpMethod ?? "GET",
            "requestHeaders": filteredRequestHeaders ?? [:],
            "requestBody": requestBodyString,
            "responseHeaders": filteredResponseHeaders,
            "statusCode": httpResponse.statusCode,
        ]
        responseObject["responseData"] = String(data: responseData, encoding: .utf8) ?? ""
        
        let sortedResponseObject = responseObject.sorted { $0.key < $1.key }
        
        return try JSONSerialization.data(
            withJSONObject: Dictionary(uniqueKeysWithValues: sortedResponseObject),
            options: .prettyPrinted
        )
    }
    
    public func decodeDataTaskResult(request: URLRequest, data: Data) throws -> (httpURLResponse: HTTPURLResponse, responseData: Data) {
        
        guard let url = request.url else {
            throw NSError(domain: "Invalid URL", code: -1, userInfo: nil)
        }
        
        guard let responseObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let responseDataString = responseObject["responseData"] as? String,
              let responseData = responseDataString.data(using: .utf8),
              var responseHeaders = responseObject["responseHeaders"] as? [String: String],
              let statusCode = responseObject["statusCode"] as? Int else {
            throw NSError(domain: "Failed to decode saved data", code: -1, userInfo: nil)
        }
        
        responseHeaders["X-SwiftNetworkReplay"] = "true"
        
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: responseHeaders
        ) else {
            throw NSError(domain: "Failed to create a HTTPURLResponse", code: -1, userInfo: nil)
        }
        
        return (
            httpURLResponse: response,
            responseData: responseData
        )
    }
}
