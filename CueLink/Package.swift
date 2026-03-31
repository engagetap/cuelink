// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CueLink",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "CueLink",
            dependencies: ["Sparkle"],
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
