// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "NotificationKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "NotificationKit", targets: ["NotificationKit"]),
    ],
    targets: [
        .target(name: "NotificationKit"),
        .testTarget(
            name: "NotificationKitTests",
            dependencies: ["NotificationKit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
