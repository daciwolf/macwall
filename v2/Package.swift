// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacWallV2",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "MacWallV2",
            targets: ["MacWallV2"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "MacWallV2"
        ),
        .testTarget(
            name: "MacWallV2Tests",
            dependencies: ["MacWallV2"]
        ),
    ]
)
