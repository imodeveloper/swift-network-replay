//
//  String+Conveniences.swift
//  SwiftNetworkReplay
//
//  Created by Ivan Borinschi on 29.11.2024.
//

import Foundation

extension String {
    func addUnderliyngError(_ error: Error?) -> String {
        if let error {
            return self + "\nUnderlyingError: \(error.localizedDescription)"
        }
        return self
    }
}
