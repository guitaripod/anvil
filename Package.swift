// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Anvil",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "Anvil",
            targets: ["Anvil"]
        ),
    ],
    targets: [
        .target(
            name: "Anvil"
        ),
    ]
)
