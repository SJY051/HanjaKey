// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HanjaKey",
    platforms: [.macOS(.v13)],
    dependencies: [
        // Global, user-customizable hotkeys (min macOS 10.15; SwiftUI recorder UI).
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
    ],
    targets: [
        // Pure conversion engine — NO AppKit/SwiftUI. The warm-up's TDD centerpiece.
        .target(
            name: "HanjaKitCore",
            resources: [.copy("Resources")]
        ),
        // Menu-bar agent app shell (AppKit NSStatusItem + nonactivating NSPanel hosting SwiftUI).
        .executableTarget(
            name: "HanjaKey",
            dependencies: [
                "HanjaKitCore",
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ]
        ),
        .testTarget(
            name: "HanjaKitCoreTests",
            dependencies: ["HanjaKitCore"]
        ),
    ]
)
