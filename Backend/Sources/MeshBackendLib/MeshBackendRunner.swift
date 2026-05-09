import Foundation
import MeshBackendCore

public enum MeshBackendRunner {
    public static func run() async throws {
        let port = UInt16(ProcessInfo.processInfo.environment["PORT"] ?? "8080") ?? 8080
        let persistenceURL = URL(fileURLWithPath: ProcessInfo.processInfo.environment["MESH_BACKEND_SNAPSHOT_PATH"] ?? ".mesh-backend/incidents.json")
        let store = MeshBackendStore(persistenceURL: persistenceURL)
        let router = MeshBackendRouter(store: store)
        let ingester = DataSFIngester(store: store)

        try await ingester.ingestOnce()
        Task {
            await ingester.ingestOnCadence()
        }

        let server = MeshNIOHTTPServer(router: router, port: port)
        try await server.start()
        print("MeshBackend listening on http://0.0.0.0:\(port)")
        while true {
            try await Task.sleep(nanoseconds: 60_000_000_000)
        }
    }
}

public struct DataSFIngester {
    public let store: MeshBackendStore
    public var session: URLSession = .shared
    public var intervalNanoseconds: UInt64 = 600_000_000_000

    public init(store: MeshBackendStore) {
        self.store = store
    }

    public func ingestOnCadence() async {
        while !Task.isCancelled {
            do {
                try await Task.sleep(nanoseconds: intervalNanoseconds)
                try await ingestOnce()
            } catch {
                await store.recordError(
                    APIErrorPayload(code: .sourceUnavailable, message: error.localizedDescription, retryAfterSeconds: nil)
                )
            }
        }
    }

    public func ingestOnce() async throws {
        var components = URLComponents(url: MeshBackendContract.dataSFDispatchedCallsSource.url, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "$limit", value: String(MeshBackendDefaults.dataSFLimit)),
            URLQueryItem(name: "$order", value: "call_last_updated_at DESC")
        ]
        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Mesh Backend (San Francisco public-safety monitor)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            guard (200...299).contains(httpResponse.statusCode) else {
                await store.recordError(
                    APIErrorPayload(
                        code: httpResponse.statusCode == 429 ? .rateLimited : .sourceUnavailable,
                        message: "DataSF returned HTTP \(httpResponse.statusCode).",
                        retryAfterSeconds: httpResponse.statusCode == 429 ? 60 : nil
                    )
                )
                return
            }
            let snapshot = try DataSFNormalizer.snapshot(from: data, fetchedAt: Date())
            await store.ingest(snapshot)
        } catch let error as DecodingError {
            await store.recordError(
                APIErrorPayload(code: .schemaDrift, message: error.localizedDescription, retryAfterSeconds: nil)
            )
        } catch {
            await store.recordError(
                APIErrorPayload(code: .sourceUnavailable, message: error.localizedDescription, retryAfterSeconds: nil)
            )
        }
    }
}
