// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VideoPlayerKit",
    platforms: [
        .macOS(.v15),
        .iOS(.v17),
        .tvOS(.v17)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "VideoPlayerKit",
            targets: ["VideoPlayerKit"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "VideoPlayerKit",
            dependencies: [
                .target(name: "VLCKit", condition: .when(platforms: [.macOS])),
                .target(name: "MobileVLCKit", condition: .when(platforms: [.iOS])),
                .target(name: "TVVLCKit", condition: .when(platforms: [.tvOS]))
            ]
        ),
        .binaryTarget(
            name: "VLCKit",
            url: "https://github.com/digitaldem/VideoPlayerKit/releases/download/0.0.0/VLCKit.xcframework.zip",
            checksum: "63964bc802e59bd63631bdfdcf5bb68cbba005d121538c42a340c7eaed9cadf2"
        ),
        .binaryTarget(
            name: "MobileVLCKit",
            url: "https://github.com/digitaldem/VideoPlayerKit/releases/download/0.0.0/MobileVLCKit.xcframework.zip",
            checksum: "8a54c696f944289c3c9c31b7dacc054335b8a4531baeafcaea32353ee01358ba"
        ),
        .binaryTarget(
            name: "TVVLCKit",
            url: "https://github.com/digitaldem/VideoPlayerKit/releases/download/0.0.0/TVVLCKit.xcframework.zip",
            checksum: "8f09adb6b860d13ddba42d9cdcd797f248e8bc81b5f24984453ce7cd548ef7a5"
        ),
        .testTarget(
            name: "VideoPlayerKitTests",
            dependencies: ["VideoPlayerKit"]
        ),
    ]
)
