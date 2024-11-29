//
//  SwiftNetworkReplayTests.swift
//  SwiftNetworkReplayTests
//
//  Created by Ivan Borinschi on 22.11.2024.
//

import Testing
@testable import SwiftNetworkReplay

struct SwiftNetworkReplayTests {
    
    let service = JsonplaceholderService()
    
    @Test
    func handleNoRecordFound() async throws {
        SwiftNetworkReplay.start()
        try SwiftNetworkReplay.removeRecordingDirectory()
        await #expect(throws: Error.self) {
            let _ = try await service.getPosts()
        }
    }
    
    @Test
    func addAndReadNewRecord() async throws {
        SwiftNetworkReplay.start(isRecordingEnabled: true)
        try SwiftNetworkReplay.removeRecordingDirectory()
        
        // Perform the GET request
        var post = try await service.getPost(byId: 1)
        #expect(post.result.id == 1)
        
        SwiftNetworkReplay.start()
        
        post = try await service.getPost(byId: 1)
        #expect(post.result.id == 1)
        #expect(post.isSwiftNetworkReplay)
        
        try SwiftNetworkReplay.removeRecordingDirectory()
    }
    
    @Test
    func retrievePostsSuccessfully() async throws {
        SwiftNetworkReplay.start()
        let posts = try await service.getPosts()
        print(posts.headers)
        #expect(!posts.result.isEmpty)
        #expect(posts.isSwiftNetworkReplay)
    }
    
    @Test
    func sendPostSuccessfully() async throws {
        SwiftNetworkReplay.start()
        let newPost = try await service.sendPost(title: "Hello World", body: "This is a test", userId: 1)
        #expect(newPost.result.id != 0)
        #expect(newPost.isSwiftNetworkReplay)
    }
    
    @Test
    func retrieveUserSuccessfully() async throws {
        SwiftNetworkReplay.start()
        let user = try await service.getUser(byId: 1)
        #expect(user.result.name == "Leanne Graham")
        #expect(user.isSwiftNetworkReplay)
    }
    
    @Test
    func handleMultipleRequests() async throws {
        SwiftNetworkReplay.start()
        let posts = try await service.getPosts()
        let newPost = try await service.sendPost(title: "Hello World", body: "This is a test", userId: 1)
        let user = try await service.getUser(byId: 1)
        #expect(!posts.result.isEmpty)
        #expect(newPost.result.id != 0)
        #expect(user.result.name == "Leanne Graham")
        #expect(posts.isSwiftNetworkReplay)
        #expect(newPost.isSwiftNetworkReplay)
        #expect(user.isSwiftNetworkReplay)
    }
    
    @Test
    func restrictToAllowedDomains() async throws {
        SwiftNetworkReplay.start(urlKeywordsForReplay: ["google.com"])
        let user = try await service.getUser(byId: 1)
        #expect(user.result.name == "Leanne Graham")
        #expect(!user.isSwiftNetworkReplay)
        
        SwiftNetworkReplay.start(urlKeywordsForReplay: ["jsonplaceholder.typicode.com"])
        let newPost = try await service.sendPost(title: "Hello World", body: "This is a test", userId: 1)
        #expect(newPost.isSwiftNetworkReplay)
    }
}
