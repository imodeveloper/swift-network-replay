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
        SwiftNetworkReplay.start()
        let posts = try await service.getPosts()
        print(posts.headers)
        #expect(!posts.result.isEmpty, "Posts should not be empty")
        #expect(posts.isSwiftNetworkReplay, "Posts should be SwiftNetworkReplay")
    }
    
    @Test
    func testSendPost() async throws {
        SwiftNetworkReplay.start()
        let newPost = try await service.sendPost(title: "Hello World", body: "This is a test", userId: 1)
        #expect(newPost.result.id != 0, "New post should have an ID assigned by the server")
        #expect(newPost.isSwiftNetworkReplay, "Posts should be SwiftNetworkReplay")
    }
    
    @Test
    func testGetUser() async throws {
        SwiftNetworkReplay.start()
        let user = try await service.getUser(byId: 1)
        #expect(user.result.name == "Leanne Graham", "User's name should match")
        #expect(user.isSwiftNetworkReplay, "Posts should be SwiftNetworkReplay")
    }
    
    @Test
    func testMultipleRequests() async throws {
        SwiftNetworkReplay.start()
        let posts = try await service.getPosts()
        let newPost = try await service.sendPost(title: "Hello World", body: "This is a test", userId: 1)
        let user = try await service.getUser(byId: 1)
        #expect(!posts.result.isEmpty, "Posts should not be empty")
        #expect(newPost.result.id != 0, "New post should have an ID assigned by the server")
        #expect(user.result.name == "Leanne Graham", "User's name should match")
        #expect(posts.isSwiftNetworkReplay, "Posts should be SwiftNetworkReplay")
        #expect(newPost.isSwiftNetworkReplay, "Posts should be SwiftNetworkReplay")
        #expect(user.isSwiftNetworkReplay, "Posts should be SwiftNetworkReplay")
    }
    
    @Test
    func testOnlyAlowedDoemains() async throws {
        SwiftNetworkReplay.start()
        SwiftNetworkReplay.setAllowedDomains(["google.com"])
        let user = try await service.getUser(byId: 1)
        #expect(user.result.name == "Leanne Graham", "User's name should match")
        #expect(!user.isSwiftNetworkReplay, "Posts should NOT be SwiftNetworkReplay")
        
        SwiftNetworkReplay.start()
        SwiftNetworkReplay.setAllowedDomains(["jsonplaceholder.typicode.com"])
        let newPost = try await service.sendPost(title: "Hello World", body: "This is a test", userId: 1)
        #expect(newPost.isSwiftNetworkReplay, "Posts should BE SwiftNetworkReplay")
    }
}
