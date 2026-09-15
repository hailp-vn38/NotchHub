// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "NotchHub",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "NotchDomain", targets: ["NotchDomain"]),
        .library(name: "NotchCore", targets: ["NotchCore"]),
        .library(name: "NotchSurface", targets: ["NotchSurface"]),
        .library(name: "NotchUI", targets: ["NotchUI"]),
        .library(name: "NotchActions", targets: ["NotchActions"]),
        .library(name: "NotchIPC", targets: ["NotchIPC"]),
    ],
    targets: [
        .target(name: "NotchDomain", path: "Packages/NotchDomain/Sources"),
        .target(
            name: "NotchCore",
            dependencies: ["NotchDomain"],
            path: "Packages/NotchCore/Sources"
        ),
        .target(
            name: "NotchSurface",
            dependencies: ["NotchCore", "NotchDomain"],
            path: "Packages/NotchSurface/Sources"
        ),
        .target(
            name: "NotchUI",
            dependencies: ["NotchDomain"],
            path: "Packages/NotchUI/Sources"
        ),
        .target(
            name: "NotchActions",
            dependencies: ["NotchCore", "NotchDomain"],
            path: "Packages/NotchActions/Sources"
        ),
        .target(
            name: "NotchIPC",
            dependencies: ["NotchCore", "NotchDomain"],
            path: "Packages/NotchIPC/Sources"
        ),
        .testTarget(
            name: "NotchPackageSpineTests",
            dependencies: ["NotchCore", "NotchDomain", "NotchSurface"],
            path: "Tests/NotchPackageSpineTests"
        ),
        .testTarget(
            name: "NotchUITests",
            dependencies: ["NotchUI"],
            path: "Tests/NotchUITests"
        ),
    ]
)
