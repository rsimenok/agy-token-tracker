// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AGVTokenTracker",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AGVTokenTracker", targets: ["AGVTokenTracker"])
    ],
    targets: [
        .executableTarget(
            name: "AGVTokenTracker",
            path: "Sources/AGVTokenTracker"
        ),
        .testTarget(
            name: "AGVTokenTrackerTests",
            dependencies: ["AGVTokenTracker"],
            path: "Tests/AGVTokenTrackerTests"
        )
    ]
)
