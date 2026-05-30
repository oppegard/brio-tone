// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BrioTone",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "BrioTone",
            path: "Sources/BrioTone"
        )
    ]
)
