import MeshBackendLib

@main
struct MeshBackendMain {
    static func main() async throws {
        try await MeshBackendRunner.run()
    }
}
