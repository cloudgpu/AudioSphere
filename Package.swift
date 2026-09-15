// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "AudioSphere",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "AudioSphere",
            path: "Sources/AudioSphere"
        )
    ]
)
