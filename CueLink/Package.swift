// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CueLink",
    platforms: [.macOS(.v14)],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "CueLink",
            dependencies: [],
            path: "CueLink",
            exclude: ["Info.plist", "Assets.xcassets"],
            resources: [
                .copy("Resources")
            ]
        ),
        .testTarget(
            name: "CueLinkTests",
            dependencies: ["CueLink"],
            path: "CueLinkTests"
        ),
    ]
)
