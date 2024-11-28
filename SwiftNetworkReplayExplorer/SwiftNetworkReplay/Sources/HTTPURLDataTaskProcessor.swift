//
//  HTTPURLDataTaskProcessor.swift
//  SwiftNetworkReplay
//
//  Created by Ivan Borinschi on 22.11.2024.
//

import Foundation

public protocol HTTPDataTaskSerializer {
    func encode(request: URLRequest, responseData: Data, httpResponse: HTTPURLResponse) throws -> Data
    func decode(request: URLRequest, data: Data) throws -> (httpURLResponse: HTTPURLResponse, responseData: Data)
}

public final class DefaultHTTPDataTaskSerializer: HTTPDataTaskSerializer {
    
    public func encode(request: URLRequest, responseData: Data, httpResponse: HTTPURLResponse) throws -> Data {

        // Convert headers to [String: String]
        let responseHeaders = convertHeadersToStringDict(httpResponse.allHeaderFields)
        let requestHeaders = request.allHTTPHeaderFields ?? [:]

        // Get Content-Type headers
        let requestContentType = request.value(forHTTPHeaderField: "Content-Type")
        let responseContentType = httpResponse.value(forHTTPHeaderField: "Content-Type")

        // Encode request body
        let (requestBodyString, isRequestBodyBase64Encoded) = encodeDataToString(request.httpBody, contentType: requestContentType)

        // Encode response data
        let (responseDataString, isResponseDataBase64Encoded) = encodeDataToString(responseData, contentType: responseContentType)

        let responseObject: [String: Any] = [
            "service": request.url?.absoluteString ?? "unknown_service",
            "requestType": request.httpMethod ?? "GET",
            "requestHeaders": requestHeaders,
            "requestBody": [
                "data": requestBodyString,
                "isBase64Encoded": isRequestBodyBase64Encoded
            ],
            "responseHeaders": responseHeaders,
            "statusCode": httpResponse.statusCode,
            "responseData": [
                "data": responseDataString,
                "isBase64Encoded": isResponseDataBase64Encoded
            ]
        ]

        return try JSONSerialization.data(withJSONObject: responseObject, options: .prettyPrinted)
    }
    
    public func decode(request: URLRequest, data: Data) throws -> (httpURLResponse: HTTPURLResponse, responseData: Data) {
        
        guard let url = request.url else {
            throw NSError(domain: "HTTPURLDataTaskProcessorError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL in the request."])
        }
        
        // Deserialize JSON
        guard let responseObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            throw NSError(domain: "HTTPURLDataTaskProcessorError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to deserialize JSON data."])
        }

        // Decode response data
        guard let responseDataDict = responseObject["responseData"] as? [String: Any],
              let responseDataString = responseDataDict["data"] as? String,
              let isResponseDataBase64Encoded = responseDataDict["isBase64Encoded"] as? Bool,
              let responseData = decodeStringToData(responseDataString, isBase64Encoded: isResponseDataBase64Encoded) else {
            throw NSError(domain: "HTTPURLDataTaskProcessorError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Response data is missing or corrupted."])
        }

        // Extract and convert headers
        guard let responseHeadersAny = responseObject["responseHeaders"] as? [String: Any] else {
            throw NSError(domain: "HTTPURLDataTaskProcessorError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Response headers are missing or invalid."])
        }
        var responseHeaders = convertHeadersToStringDict(responseHeadersAny)
        responseHeaders["X-SwiftNetworkReplay"] = "true"
        
        // Extract status code
        guard let statusCode = responseObject["statusCode"] as? Int else {
            throw NSError(domain: "HTTPURLDataTaskProcessorError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Status code is missing or invalid."])
        }
        
        // Create HTTPURLResponse
        guard let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: responseHeaders) else {
            throw NSError(domain: "HTTPURLDataTaskProcessorError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create HTTPURLResponse."])
        }
        
        return (httpURLResponse: response, responseData: responseData)
    }
    
    // Helper function to convert headers to [String: String]
    private func convertHeadersToStringDict(_ headers: [AnyHashable: Any]) -> [String: String] {
        var stringHeaders: [String: String] = [:]
        for (key, value) in headers {
            if let keyString = key as? String {
                stringHeaders[keyString] = "\(value)"
            }
        }
        return stringHeaders
    }

    // Helper function to encode Data to String
    private func encodeDataToString(_ data: Data?, contentType: String?) -> (dataString: String, isBase64Encoded: Bool) {
        guard let data = data else {
            return ("", false)
        }

        if let contentType = contentType, isTextContentType(contentType) {
            // Attempt to decode data using the specified charset, default to UTF-8
            let encoding = contentTypeCharset(contentType) ?? .utf8
            if let string = String(data: data, encoding: encoding) {
                return (string, false)
            }
        }

        // Fallback to base64 encoding for binary data
        return (data.base64EncodedString(), true)
    }
    
    // Helper to determine if Content-Type is text
    private func isTextContentType(_ contentType: String) -> Bool {
        // Check if Content-Type starts with "text/"
        if contentType.lowercased().hasPrefix("text/") {
            return true
        }

        // List of known text Content-Types
        let textTypes: Set<String> = [
            "application/json",
            "application/xml",
            "application/javascript",
            "application/xhtml+xml",
            "application/x-www-form-urlencoded"
        ]

        let mimeType = contentType.components(separatedBy: ";").first?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return textTypes.contains(mimeType)
    }

    // Helper to extract charset from Content-Type
    private func contentTypeCharset(_ contentType: String) -> String.Encoding? {
        // Extract charset from Content-Type header
        let parameters = contentType.components(separatedBy: ";").dropFirst()
        for parameter in parameters {
            let keyValue = parameter.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "=")
            if keyValue.count == 2, keyValue[0].lowercased() == "charset" {
                let charset = keyValue[1].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return stringEncoding(forCharset: charset)
            }
        }
        // Default to UTF-8
        return .utf8
    }

    // Map charset to String.Encoding
    private func stringEncoding(forCharset charset: String) -> String.Encoding? {
        switch charset {
        case "utf-8":
            return .utf8
        case "utf-16":
            return .utf16
        case "iso-8859-1", "latin1":
            return .isoLatin1
        // Add other encodings as needed
        default:
            return nil
        }
    }

    // Helper function to decode String to Data
    private func decodeStringToData(_ string: String, isBase64Encoded: Bool) -> Data? {
        if isBase64Encoded {
            return Data(base64Encoded: string)
        } else {
            return string.data(using: .utf8)
        }
    }
}
