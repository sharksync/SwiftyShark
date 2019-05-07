// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "SwiftyShark",
    products: [
        .library(name: "SwiftyShark", targets: ["SwiftyShark"]),
    ],
    dependencies: [
        .package(url: "https://github.com/VeldsparCrypto/CSQlite.git", .exact("1.0.8")),
    ],
    targets: [
        .target(
            name: "SwiftyShark",
            dependencies: [],
            path: "./Sources"),
    ],
    swiftLanguageVersions: [
        4
    ]
)
