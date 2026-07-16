// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "RealityKitContent",
    platforms: [
        .visionOS(.v26),
    ],
    products: [
        .library(
            name: "RealityKitContent",
            targets: ["RealityKitContent"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "RealityKitContent",
            dependencies: [],
            swiftSettings: [
                .enableUpcomingFeature("MemberImportVisibility"),
            ]
        ),
    ]
)
