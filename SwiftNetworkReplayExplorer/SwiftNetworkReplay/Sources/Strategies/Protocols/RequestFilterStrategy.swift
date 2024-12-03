//
//  RequestFilterStrategy.swift
//  SwiftNetworkReplayExplorer
//
//  Created by Ivan Borinschi on 03.12.2024.
//


public protocol RequestFilterStrategy {
    func shouldHandle(request: URLRequest) -> Bool
}

extension Array: RequestFilterStrategy where Element == RequestFilterStrategy {
    public func shouldHandle(request: URLRequest) -> Bool {
        for task in self {
            if task.shouldHandle(request: request) {
                continue
            } else {
                return false
            }
        }
        return true
    }
}
