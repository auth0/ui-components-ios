// swift-tools-version:6.0

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v5)
]

let package = Package(
    name: "Auth0UniversalComponents",
    platforms: [.iOS(.v16), .macOS(.v13), .visionOS(.v1)],
    products: [.library(name: "Auth0UniversalComponents", targets: ["Auth0UniversalComponents"])],
    dependencies: [
        .package(url: "https://github.com/auth0/Auth0.swift.git", exact:"2.16.1")
    ],
    targets: [
        .target(
            name: "Auth0UniversalComponents", 
            dependencies: [
                .product(name: "Auth0", package: "Auth0.swift")
            ],
            path: "Auth0UniversalComponents",
            exclude: ["Info.plist"],
            resources: [.copy("PrivacyInfo.xcprivacy"), .process("Resources/Media/Media.xcassets"), .process("Resources/Colors/Colors.xcassets"), .copy("Resources/Fonts")],
            swiftSettings: swiftSettings),
        .testTarget(
            name: "Auth0UniversalComponentsTests",
            dependencies: [
                "Auth0UniversalComponents",
                .product(name: "Auth0", package: "Auth0.swift")
            ],
            path: "Auth0UniversalComponentsTests",
            exclude: ["Info.plist", "Auth0.plist"],
            swiftSettings: swiftSettings)
    ]
)
