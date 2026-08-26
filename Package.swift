// swift-tools-version:6.0
//
//  Package.swift
//  CDYahooKit
//
//  Copyright (c) 2016-2026 Christopher de Haan <contact@christopherdehaan.me>
//

import PackageDescription

let package = Package(
    name: "CDYahooKit",
    platforms: [.iOS(.v15), .macOS(.v12), .tvOS(.v15), .watchOS(.v8), .visionOS(.v1)],
    products: [
        .library(name: "CDYahooKit", targets: ["CDYahooKit"]),
        .library(name: "CDYahooKitDynamic", type: .dynamic, targets: ["CDYahooKit"]),
        .library(name: "CDYahooKitTesting", targets: ["CDYahooKitTesting"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.3.0")
    ],
    targets: [
        .target(name: "CDYahooKit",
                path: "Source",
                exclude: ["Testing"],
                swiftSettings: [.enableUpcomingFeature("ExistentialAny")]),
        .target(name: "CDYahooKitTesting",
                path: "Source/Testing",
                swiftSettings: [.enableUpcomingFeature("ExistentialAny")]),
        .testTarget(name: "CDYahooKitTests",
                    dependencies: ["CDYahooKit", "CDYahooKitTesting"],
                    path: "Tests/CDYahooKitTests",
                    resources: [.process("Fixtures")])
    ],
    swiftLanguageModes: [.v6]
)
