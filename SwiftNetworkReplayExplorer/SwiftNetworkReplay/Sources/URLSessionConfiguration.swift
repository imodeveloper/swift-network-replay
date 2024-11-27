//
//  URLSessionConfiguration.swift
//  SwiftNetworkReplay
//
//  Created by Ivan Borinschi on 26.11.2024.
//

import Foundation

public extension URLSessionConfiguration {
    static let swizzleSwiftNetworkReplay: Void = {
        let originalSelector = #selector(getter: protocolClasses)
        let swizzledSelector = #selector(getter: swizzled_protocolClasses)
        
        if let originalMethod = class_getInstanceMethod(URLSessionConfiguration.self, originalSelector),
           let swizzledMethod = class_getInstanceMethod(URLSessionConfiguration.self, swizzledSelector) {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }()
    
    @objc var swizzled_protocolClasses: [AnyClass]? {
        var protocols = self.swizzled_protocolClasses ?? []
        if !protocols.contains(where: { $0 == SwiftNetworkReplay.self }) {
            protocols.insert(SwiftNetworkReplay.self, at: 0)
        }
        return protocols
    }
}
