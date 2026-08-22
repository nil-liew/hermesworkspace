// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SimpleVLCPlayer",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "SimpleVLCPlayer",
            path: "Sources"
        )
    ]
)
