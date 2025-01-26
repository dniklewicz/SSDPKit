// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SSDPKit",
    platforms: [.macOS(.v13), .iOS(.v15)],
    products: [
        .library(
            name: "SSDPKit",
            targets: ["SSDPKit"]),
        .executable(name: "SSDPClientExample", targets: ["SSDPClientExample"])
    ],
    targets: [
        .target(
            name: "SSDPKit"
		),
        .executableTarget(name: "SSDPClientExample", dependencies: ["SSDPKit"]),
        .testTarget(
            name: "SSDPClientTests",
            dependencies: ["SSDPKit"])
    ]
)
