// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Paneless",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Paneless",
            dependencies: ["PanelessKit"],
            path: "Sources/Paneless"
        ),
        .target(
            name: "PanelessKit",
            path: "Sources/PanelessKit",
            linkerSettings: [
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("Carbon"),
            ]
        ),
        .testTarget(
            name: "PanelessKitTests",
            dependencies: ["PanelessKit"],
            path: "Tests/PanelessKitTests"
        ),
    ]
)
