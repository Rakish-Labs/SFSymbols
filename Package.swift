// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "SFSymbols",
    platforms: [.iOS(.v12), .tvOS(.v12), .watchOS(.v5), .macOS(.v10_14), .visionOS(.v1)],
    products: [
        .library(name: "SFSymbols", targets: ["SFSymbols"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SFSymbols",
            dependencies: []
        ),
        .testTarget(
            name: "SFSymbolsTests",
            dependencies: ["SFSymbols"]
        ),
    ]
)
