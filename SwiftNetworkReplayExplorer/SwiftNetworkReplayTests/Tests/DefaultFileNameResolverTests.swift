//
//  DefaultFileNameResolverTests.swift
//  SwiftNetworkReplayExplorer
//
//  Created by Ivan Borinschi on 22.11.2024.
//


import Testing
@testable import SwiftNetworkReplay

struct DefaultFileNameResolverTests {
    let resolver = DefaultFileNameResolver()

    @Test
    func testResolveFileNameWithBasicInputs() async throws {
        let url = URL(string: "https://example.com/path")!
        var request = URLRequest(url: url)
        request.addValue("Bearer token", forHTTPHeaderField: "Authorization")
        request.httpBody = "test body".data(using: .utf8)
        let testName = "TestCase"

        let fileName = resolver.resolveFileName(for: request, testName: testName)

        #expect(fileName.hasSuffix(".json"), "File name should have a .json suffix")
        #expect(fileName.contains("example.com"), "File name should include the formatted domain name")
        #expect(!fileName.isEmpty, "File name should not be empty")
    }

    @Test
    func testResolveFileNameWithEmptyHeadersAndBody() async throws {
        let url = URL(string: "https://example.com/anotherPath")!
        let request = URLRequest(url: url)
        let testName = "EmptyHeadersAndBody"

        let fileName = resolver.resolveFileName(for: request, testName: testName)

        #expect(fileName.hasSuffix(".json"), "File name should have a .json suffix")
        #expect(fileName.contains("example.com"), "File name should include the formatted domain name")
        #expect(fileName.contains("GET_example.com_anotherPath_6223cf28ec7d110a.json"), "Exact name")
    }

    @Test
    func testResolveFileNameWithSortedHeaders() async throws {
        let url = URL(string: "https://example.com/sortedHeaders")!
        var request = URLRequest(url: url)
        request.addValue("Bearer token", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = "another test body".data(using: .utf8)
        let testName = "SortedHeaders"

        let fileName = resolver.resolveFileName(for: request, testName: testName)

        #expect(fileName.contains("example.com"), "File name should include the formatted domain name")
        #expect(fileName.contains("GET_example.com_sortedHeaders_be25cb756b9e02fa.json"), "Exact name")
    }

    @Test
    func testResolveFileNameWithUnknownDomain() async throws {
        let url = URL(string: "unknown")!
        var request = URLRequest(url: url)
        request.addValue("Bearer token", forHTTPHeaderField: "Authorization")
        request.httpBody = "body with unknown domain".data(using: .utf8)
        let testName = "UnknownDomain"

        let fileName = resolver.resolveFileName(for: request, testName: testName)
        #expect(fileName.contains("unknown"), "File name should use 'unknown' for invalid domains")
        #expect(fileName.hasSuffix(".json"), "File name should have a .json suffix")
    }
}

