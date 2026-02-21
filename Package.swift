// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ClipboardManager",
    platforms: [
        .macOS(.v26)
    ],
    dependencies: [
        .package(url: "https://github.com/soffes/HotKey", from: "0.2.1")
    ],
    targets: [
        .executableTarget(
            name: "ClipboardManager",
            dependencies: ["HotKey"],
            path: "Sources/ClipboardManager"
        )
    ]
)
