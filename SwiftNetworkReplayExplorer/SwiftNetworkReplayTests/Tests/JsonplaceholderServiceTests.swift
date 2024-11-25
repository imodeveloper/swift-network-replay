//
//  JsonplaceholderService.swift
//  SwiftNetworkReplayExplorer
//
//  Created by Ivan Borinschi on 22.11.2024.
//

import Testing
@testable import SwiftNetworkReplay

struct JsonplaceholderServiceTests {
    let service = JsonplaceholderService()
    
    @Test
    func testGetPosts() async throws {
        SwiftNetworkReplay.start(record: true)
        let posts = try await service.getPosts()
        #expect(!posts.isEmpty, "Posts should not be empty")
    }
    
    @Test
    func testSendPost() async throws {
        SwiftNetworkReplay.start(record: true)
        let newPost = try await service.sendPost(title: "Hello World", body: "This is a test", userId: 1)
        #expect(newPost.id != 0, "New post should have an ID assigned by the server")
    }
    
    @Test
    func testGetUser() async throws {
        SwiftNetworkReplay.start(record: true)
        let user = try await service.getUser(byId: 1)
        #expect(user.name == "Leanne Graham", "User's name should match")
    }
    
    @Test
    func testMultipleRequests() async throws {
        SwiftNetworkReplay.start(record: true)
        let posts = try await service.getPosts()
        let newPost = try await service.sendPost(title: "Hello World", body: "This is a test", userId: 1)
        let user = try await service.getUser(byId: 1)
        #expect(!posts.isEmpty, "Posts should not be empty")
        #expect(newPost.id != 0, "New post should have an ID assigned by the server")
        #expect(user.name == "Leanne Graham", "User's name should match")
    }
}
