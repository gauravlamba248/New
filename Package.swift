// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Aegis",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Aegis", targets: ["Aegis"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Aegis",
            dependencies: [],
            path: "Sources/Aegis"
        )
    ]
)
