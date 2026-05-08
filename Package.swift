// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Mesh",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Mesh", targets: ["Mesh"]),
        .library(name: "MeshBackendCore", targets: ["MeshBackendCore"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Mesh",
            dependencies: [],
            path: "Mesh",
            exclude: [
                "Info.plist",
                "Mesh.entitlements"
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "MeshBackendCore",
            dependencies: [],
            path: "Backend/Sources/MeshBackendCore"
        ),
        .testTarget(
            name: "MeshTests",
            dependencies: ["Mesh", "MeshBackendCore"],
            path: "Tests/MeshTests"
        )
    ]
)

