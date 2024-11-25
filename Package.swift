// swift-tools-version:5.8
import PackageDescription

let package = Package(
    name: "SwiftNetworkReplay",
    platforms: [
        .iOS(.v16) // Specify iOS 16 and higher
    ],
    products: [
        .library(
            name: "SwiftNetworkReplay",
            targets: ["SwiftNetworkReplay"]
        ),
    ],
    targets: [
        .target(
            name: "SwiftNetworkReplay",
            dependencies: [],
            path: "SwiftNetworkReplayExplorer/SwiftNetworkReplay/Sources"
        )
    ]
)