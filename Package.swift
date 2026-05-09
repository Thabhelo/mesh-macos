// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Mesh",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Mesh", targets: ["Mesh"]),
        .executable(name: "MeshBackend", targets: ["MeshBackend"]),
        .library(name: "MeshBackendCore", targets: ["MeshBackendCore"]),
        .library(name: "MeshBackendLib", targets: ["MeshBackendLib"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.62.0")
    ],
    targets: [
        .executableTarget(
            name: "Mesh",
            dependencies: ["MeshBackendCore"],
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
        .target(
            name: "MeshBackendLib",
            dependencies: [
                "MeshBackendCore",
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio")
            ],
            path: "Backend/Sources/MeshBackendLib"
        ),
        .executableTarget(
            name: "MeshBackend",
            dependencies: ["MeshBackendLib"],
            path: "Backend/Sources/MeshBackend"
        ),
        .testTarget(
            name: "MeshTests",
            dependencies: ["Mesh", "MeshBackendCore"],
            path: "Tests/MeshTests"
        )
    ]
)

