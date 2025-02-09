// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SSDPKit",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(
            name: "SSDPKit",
            targets: ["SSDPKit"]),
        .executable(name: "SSDPClientExample", targets: ["SSDPClientExample"])
    ],
	dependencies: [
			.package(url: "https://github.com/Kitura/BlueSocket.git", from: "2.0.2")
		],
    targets: [
        .target(
            name: "SSDPKit",
			dependencies: [.product(name: "Socket", package: "BlueSocket")]
		),
        .executableTarget(name: "SSDPClientExample", dependencies: ["SSDPKit"]),
        .testTarget(
            name: "SSDPClientTests",
            dependencies: ["SSDPKit"])
    ]
)
