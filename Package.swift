// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DSBridge",
    products: [
        .library(
            name: "DSBridge",
            targets: ["DSBridge"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/wickwirew/Runtime/", .upToNextMajor(from: "2.2.5"))
    ],
    targets: [
        .target(
            name: "DSBridge",
            dependencies: [
                "CHelper",
                "Runtime"
            ]
        ),
        .target(
            name: "CHelper",
            publicHeadersPath: "./"
        ),
        .testTarget(
            name: "DSBridgeTests",
            dependencies: ["DSBridge"]
        ),
    ]
)
