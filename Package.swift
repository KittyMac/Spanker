// swift-tools-version:5.6

import PackageDescription

let package = Package(
    name: "Spanker",
    platforms: [
        .macOS(.v10_13), .iOS(.v11)
    ],
    products: [
        .library(name: "Spanker", type: .dynamic, targets: ["Spanker"])
    ],
    dependencies: [
        .package(url: "https://github.com/KittyMac/Hitch.git", from: "0.4.0"),
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
