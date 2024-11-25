//
//  SwiftNetworkReplayTests.swift
//  SwiftNetworkReplayTests
//
//  Created by Ivan Borinschi on 22.11.2024.
//

import Testing
@testable import SwiftNetworkReplay

struct SwiftNetworkReplayTests {
    
    @Test
    func testNoRecordWasFound() async throws {
        
        SwiftNetworkReplay.start()
        try SwiftNetworkReplay.removeRecordingDirectory()
        
        guard let url = URL(string: "https://jsonplaceholder.typicode.com/posts/1") else {
            fatalError()
        }
        do {
            let (_, _) = try await URLSession.shared.data(for: URLRequest(url: url))
        } catch {
            #expect(error.localizedDescription == "The operation couldn’t be completed. (No record was found error -2.)")
        }
    }
    
    @Test
    func testAddNewRecordAndReadTheNewCreatedRecord() async throws {

        SwiftNetworkReplay.start(record: true)
        try SwiftNetworkReplay.removeRecordingDirectory()
        
        guard let url = URL(string: "https://jsonplaceholder.typicode.com/posts/1") else {
            fatalError()
        }
        
        // Perform the GET request
        let (_, response2) = try await URLSession.shared.data(for: URLRequest(url: url))
        guard let httpResponse2 = response2 as? HTTPURLResponse else { return }
        #expect(httpResponse2.statusCode == 200, "Response status code should be 200")
        
        SwiftNetworkReplay.start()
        
        // Perform the GET request
        let (_, response3) = try await URLSession.shared.data(for: URLRequest(url: url))
        guard let httpResponse3 = response3 as? HTTPURLResponse else { return }
        #expect(httpResponse3.statusCode == 200, "Response status code should be 200")
        
        try SwiftNetworkReplay.removeRecordingDirectory()
    }
}
