// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AGYTokenTracker",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AGYTokenTracker", targets: ["AGYTokenTracker"])
    ],
    targets: [
        .executableTarget(
            name: "AGYTokenTracker",
            path: "Sources/AGYTokenTracker"
        ),
        .testTarget(
            name: "AGYTokenTrackerTests",
            dependencies: ["AGYTokenTracker"],
            path: "Tests/AGYTokenTrackerTests"
        )
    ]
)
