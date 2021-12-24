// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "Spanker",
    platforms: [
        .macOS(.v10_13), .iOS(.v11)
    ],
    products: [
        .library(name: "Spanker", targets: ["Spanker"])
    ],
    dependencies: [
        .package(url: "https://github.com/KittyMac/Hitch.git", .branch("main")),
    ],
    targets: [
        .target(
            name: "Spanker",
            dependencies: [
                "Hitch"
            ]),
        .testTarget(
            name: "SpankerTests",
            dependencies: ["Spanker"]),
    ]
)
