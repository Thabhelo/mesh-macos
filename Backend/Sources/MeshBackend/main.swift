import Foundation
import MeshBackendCore
import Network

@main
struct MeshBackendMain {
    static func main() async throws {
        let port = UInt16(ProcessInfo.processInfo.environment["PORT"] ?? "8080") ?? 8080
        let persistenceURL = URL(fileURLWithPath: ProcessInfo.processInfo.environment["MESH_BACKEND_SNAPSHOT_PATH"] ?? ".mesh-backend/incidents.json")
        let store = MeshBackendStore(persistenceURL: persistenceURL)
        let router = MeshBackendRouter(store: store)
        let ingester = DataSFIngester(store: store)

        try await ingester.ingestOnce()
        Task {
            await ingester.ingestOnCadence()
        }

        let server = try MeshHTTPServer(port: port, router: router)
        try server.start()
        print("MeshBackend listening on http://127.0.0.1:\(port)")
        while true {
            try await Task.sleep(nanoseconds: 60_000_000_000)
        }
    }
}

struct DataSFIngester {
    let store: MeshBackendStore
    var session: URLSession = .shared
    var intervalNanoseconds: UInt64 = 600_000_000_000

    func ingestOnCadence() async {
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

    func ingestOnce() async throws {
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

final class MeshHTTPServer {
    private let listener: NWListener
    private let router: MeshBackendRouter

    init(port: UInt16, router: MeshBackendRouter) throws {
        self.listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
        self.router = router
    }

    func start() throws {
        listener.newConnectionHandler = { [router] connection in
            connection.start(queue: .global())
            receive(on: connection, router: router)
        }
        listener.start(queue: .global())
    }
}

private func receive(on connection: NWConnection, router: MeshBackendRouter) {
    connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { data, _, _, _ in
        guard let data, let request = String(data: data, encoding: .utf8) else {
            connection.cancel()
            return
        }

        Task {
            let parsed = parseHTTPRequest(request)
            let response = await router.route(
                method: parsed.method,
                path: parsed.path,
                queryItems: parsed.queryItems
            )
            connection.send(content: serialize(response), completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }
}

private func parseHTTPRequest(_ request: String) -> (method: String, path: String, queryItems: [URLQueryItem]) {
    let requestLine = request.components(separatedBy: "\r\n").first ?? ""
    let parts = requestLine.split(separator: " ")
    let method = parts.first.map(String.init) ?? "GET"
    let target = parts.dropFirst().first.map(String.init) ?? "/"
    let components = URLComponents(string: target)
    return (method, components?.path ?? target, components?.queryItems ?? [])
}

private func serialize(_ response: HTTPResponse) -> Data {
    var headers = response.headers
    headers["Content-Length"] = String(response.body.count)
    headers["Connection"] = "close"

    let headerText = headers
        .map { "\($0.key): \($0.value)" }
        .joined(separator: "\r\n")
    var data = Data("HTTP/1.1 \(response.statusCode) \(reasonPhrase(for: response.statusCode))\r\n\(headerText)\r\n\r\n".utf8)
    data.append(response.body)
    return data
}

private func reasonPhrase(for statusCode: Int) -> String {
    switch statusCode {
    case 200: return "OK"
    case 404: return "Not Found"
    case 500: return "Internal Server Error"
    case 503: return "Service Unavailable"
    default: return "OK"
    }
}
