// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "SpankerKit",
    platforms: [
        .macOS(.v10_13), .iOS(.v11)
    ],
    products: [
        .library(name: "SpankerKit", targets: ["SpankerKit"])
    ],
    dependencies: [
        .package(name: "HitchKit", url: "https://github.com/KittyMac/Hitch.git", .upToNextMinor(from: "0.5.0")),
    ],
    targets: [
        .target(
            name: "SpankerKit",
            dependencies: [
                "HitchKit"
            ]),
        .testTarget(
            name: "SpankerTests",
            dependencies: ["SpankerKit"]),
    ]
)
