// swift-tools-version:5.6

import PackageDescription

let package = Package(
    name: "Spanker",
    products: [
        .library(name: "Spanker", targets: ["Spanker"]),
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
