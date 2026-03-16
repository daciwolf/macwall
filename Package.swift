// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacWall",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "MacWallCore",
            targets: ["MacWallCore"]
        ),
        .executable(
            name: "MacWallApp",
            targets: ["MacWallApp"]
        ),
    ],
    targets: [
        .target(
            name: "MacWallCore"
        ),
        .executableTarget(
            name: "MacWallApp",
            dependencies: ["MacWallCore"],
            exclude: ["Resources"]
        ),
    ]
)
