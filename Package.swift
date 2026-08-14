// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HiDPIMaster",
    defaultLocalization: "en",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "HiDPIMaster",
            path: "Sources/HiDPIMaster",
            resources: [.process("Resources")]
        )
    ]
)
