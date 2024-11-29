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
        let strategy = RecordReplayStrategy.start()
        try strategy.removeRecordingSessionFolder()
        await #expect(throws: Error.self) {
            let _ = try await service.getPosts()
        }
    }
    
    @Test
    func addAndReadNewRecord() async throws {

        var strategy = RecordReplayStrategy.start(isRecordingEnabled: true)
        try strategy.removeRecordingSessionFolder()
        
        // Perform the GET request
        var post = try await service.getPost(byId: 1)
        #expect(post.result.id == 1)
        
        strategy = RecordReplayStrategy.start()
        
        post = try await service.getPost(byId: 1)
        #expect(post.result.id == 1)
        #expect(post.isSwiftNetworkReplay)
        
        try strategy.removeRecordingSessionFolder()
    }
    
    @Test
    func retrievePostsSuccessfully() async throws {
        RecordReplayStrategy.start()
        let posts = try await service.getPosts()
        print(posts.headers)
        #expect(!posts.result.isEmpty)
        #expect(posts.isSwiftNetworkReplay)
    }
    
    @Test
    func sendPostSuccessfully() async throws {
        RecordReplayStrategy.start()
        let newPost = try await service.sendPost(title: "Hello World", body: "This is a test", userId: 1)
        #expect(newPost.result.id != 0)
        #expect(newPost.isSwiftNetworkReplay)
    }
    
    @Test
    func retrieveUserSuccessfully() async throws {
        RecordReplayStrategy.start()
        let user = try await service.getUser(byId: 1)
        #expect(user.result.name == "Leanne Graham")
        #expect(user.isSwiftNetworkReplay)
    }
    
    @Test
    func handleMultipleRequests() async throws {
        RecordReplayStrategy.start()
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
        RecordReplayStrategy.start(urlKeywordsForReplay: ["google.com"])
        let user = try await service.getUser(byId: 1)
        #expect(user.result.name == "Leanne Graham")
        #expect(!user.isSwiftNetworkReplay)
        
        RecordReplayStrategy.start(urlKeywordsForReplay: ["jsonplaceholder.typicode.com"])
        let newPost = try await service.sendPost(title: "Hello World", body: "This is a test", userId: 1)
        #expect(newPost.isSwiftNetworkReplay)
    }
}
