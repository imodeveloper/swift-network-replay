//
//  HTTPURLDataTaskProcessor.swift
//  SwiftNetworkReplay
//
//  Created by Ivan Borinschi on 22.11.2024.
//

import Foundation

public protocol HTTPURLDataTaskProcessor {
    func encodeDataTaskResult(newRequest: URLRequest, data: Data, httpResponse: HTTPURLResponse) throws -> Data
    func decodeDataTaskResult(data: Data) throws -> (responseDataString: String, responseData: Data, responseHeaders: [String: String], statusCode: Int)
}

public final class DefaultHTTPURLDataTaskProcessor: HTTPURLDataTaskProcessor {
    
    public func encodeDataTaskResult(newRequest: URLRequest, data: Data, httpResponse: HTTPURLResponse) throws -> Data {
        
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
        responseObject["responseData"] = String(data: data, encoding: .utf8) ?? ""
        
        let sortedResponseObject = responseObject.sorted { $0.key < $1.key }
        
        return try JSONSerialization.data(
            withJSONObject: Dictionary(uniqueKeysWithValues: sortedResponseObject),
            options: .prettyPrinted
        )
    }
    
    public func decodeDataTaskResult(data: Data) throws -> (responseDataString: String, responseData: Data, responseHeaders: [String: String], statusCode: Int) {
        
        guard let responseObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let responseDataString = responseObject["responseData"] as? String,
              let responseData = responseDataString.data(using: .utf8),
              var responseHeaders = responseObject["responseHeaders"] as? [String: String],
              let statusCode = responseObject["statusCode"] as? Int else {
            let error = NSError(domain: "Failed to decode saved data", code: -100, userInfo: nil)
            throw error
        }
        
        responseHeaders["X-SwiftNetworkReplay"] = "true"
        
        return (
            responseDataString: responseDataString,
            responseData: responseData,
            responseHeaders: responseHeaders,
            statusCode: statusCode
        )
    }
}
