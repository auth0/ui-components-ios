// swift-tools-version:6.0

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v5)
]

let package = Package(
    name: "Auth0UIComponents",
    platforms: [.iOS(.v16), .macOS(.v13), .visionOS(.v1)],
    products: [.library(name: "Auth0UIComponents", targets: ["Auth0UIComponents"])],
    dependencies: [
        .package(url: "https://github.com/auth0/Auth0.swift.git", branch:"SDK-6839")
    ],
    targets: [
        .target(
            name: "Auth0UIComponents", 
            dependencies: [
                .product(name: "Auth0", package: "Auth0.swift")
            ],
            path: "Auth0UIComponents",
            exclude: ["Info.plist"],
            resources: [.copy("PrivacyInfo.xcprivacy"), .process("Media.xcassets")],
            swiftSettings: swiftSettings),
        .testTarget(
            name: "Auth0UIComponentsTests",
            dependencies: [
                "Auth0UIComponents",
                .product(name: "Auth0", package: "Auth0.swift")
            ],
            path: "Auth0UIComponentsTests",
            exclude: ["Info.plist", "Auth0.plist"],
            swiftSettings: swiftSettings)
    ]
)
