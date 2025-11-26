// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Mesh",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Mesh", targets: ["Mesh"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Mesh",
            dependencies: [],
            path: "Mesh",
            resources: [
                .process("Resources")
            ]
        )
    ]
)

