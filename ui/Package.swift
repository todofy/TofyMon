// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TofyUI",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "TofyUI"),
    ]
)
