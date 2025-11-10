// swift-tools-version: 6.1.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "puff",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "puff", targets: ["puff"]),
        .executable(name: "PuffHelper", targets: ["PuffHelper"])
    ],
    targets: [
        .executableTarget(
            name: "puff"
        ),
        .executableTarget(
            name: "PuffHelper",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
