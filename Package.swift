// swift-tools-version:6.0

import PackageDescription

let webAuthPlatforms: [Platform] = [.iOS, .macOS, .macCatalyst, .visionOS]
let swiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v5),
    .define("WEB_AUTH_PLATFORM", .when(platforms: webAuthPlatforms)),
    .define("PASSKEYS_PLATFORM", .when(platforms: webAuthPlatforms))
]

let package = Package(
    name: "Auth0UIComponents",
    platforms: [.iOS(.v16), .macOS(.v12), .tvOS(.v15), .watchOS(.v8), .visionOS(.v1)],
    products: [.library(name: "Auth0UIComponents", targets: ["Auth0UIComponents"])],
    dependencies: [
        .package(url: "https://github.com/auth0/Auth0.swift.git", exact:"2.15.1")
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
            swiftSettings: swiftSettings)
    ]
)
