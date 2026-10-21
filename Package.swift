// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "KnockKnock",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .executable(name: "KnockKnock", targets: ["KnockKnock"])
    ],
    targets: [
        .executableTarget(
            name: "KnockKnock",
            path: "Sources/KnockKnock",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("Accelerate"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("IOKit")
            ]
        ),
        .testTarget(
            name: "KnockKnockTests",
            dependencies: ["KnockKnock"],
            path: "Tests/KnockKnockTests"
        )
    ]
)
