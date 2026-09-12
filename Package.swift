// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ShinobiLockCore",
    platforms: [.macOS(.v13)],
    products: [.library(name: "ShinobiLockCore", targets: ["ShinobiLockCore"])],
    targets: [
        .target(name: "ShinobiLockCore", path: "Core"),
        .testTarget(name: "ShinobiLockCoreTests", dependencies: ["ShinobiLockCore"], path: "Tests")
    ]
)
