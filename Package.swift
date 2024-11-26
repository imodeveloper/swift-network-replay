// swift-tools-version:5.8
import PackageDescription

let package = Package(
    name: "SwiftNetworkReplay",
    platforms: [
        .iOS(.v14) 
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