// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SpectraNotificationSDK",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SpectraNotificationSDK",
            targets: ["SpectraNotificationSDK"]
        )
    ],
    targets: [
        .target(
            name: "SpectraNotificationSDK"
        ),
        .testTarget(
            name: "SpectraNotificationSDKTests",
            dependencies: ["SpectraNotificationSDK"]
        )
    ]
)
