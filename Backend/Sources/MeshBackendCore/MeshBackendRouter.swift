import Foundation

public struct HTTPResponse: Equatable, Sendable {
    public let statusCode: Int
    public let headers: [String: String]
    public let body: Data

    public init(statusCode: Int, headers: [String: String] = [:], body: Data) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }
}

public actor MeshBackendStore {
    private var snapshot: DataSFIncidentSnapshot?
    private var lastSuccessfulIngestAt: Date?
    private var lastError: APIErrorPayload?
    private let persistenceURL: URL?

    public init(snapshot: DataSFIncidentSnapshot? = nil, persistenceURL: URL? = nil) {
        self.persistenceURL = persistenceURL
        self.snapshot = snapshot ?? Self.loadSnapshot(from: persistenceURL)
        self.lastSuccessfulIngestAt = self.snapshot?.fetchedAt
    }

    public func ingest(_ snapshot: DataSFIncidentSnapshot) {
        self.snapshot = snapshot
        self.lastSuccessfulIngestAt = snapshot.fetchedAt
        self.lastError = nil
        persist(snapshot)
    }

    public func recordError(_ error: APIErrorPayload) {
        self.lastError = error
    }

    public func currentSnapshot() -> DataSFIncidentSnapshot? {
        snapshot
    }

    public func health(checkedAt: Date) -> BackendHealthPayload {
        let sourceStatus: BackendHealthStatus
        if snapshot == nil {
            sourceStatus = .down
        } else if lastError != nil {
            sourceStatus = .degraded
        } else {
            sourceStatus = .healthy
        }

        return BackendHealthPayload(
            status: sourceStatus,
            checkedAt: checkedAt,
            sources: [
                SourceHealthPayload(
                    source: MeshBackendContract.dataSFDispatchedCallsSource,
                    status: sourceStatus,
                    lastSuccessfulIngestAt: lastSuccessfulIngestAt,
                    lastError: lastError
                )
            ]
        )
    }

    private static func loadSnapshot(from url: URL?) -> DataSFIncidentSnapshot? {
        guard let url, let data = try? Data(contentsOf: url) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(DataSFIncidentSnapshot.self, from: data)
    }

    private func persist(_ snapshot: DataSFIncidentSnapshot) {
        guard let persistenceURL else { return }
        do {
            try FileManager.default.createDirectory(
                at: persistenceURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(snapshot).write(to: persistenceURL, options: .atomic)
        } catch {
            lastError = APIErrorPayload(
                code: .internalError,
                message: "Failed to persist incident snapshot: \(error.localizedDescription)",
                retryAfterSeconds: nil
            )
        }
    }
}

public struct MeshBackendRouter: Sendable {
    private let store: MeshBackendStore
    private let now: @Sendable () -> Date
    private let encoder: JSONEncoder

    public init(store: MeshBackendStore, now: @escaping @Sendable () -> Date = { Date() }) {
        self.store = store
        self.now = now
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    public func route(method: String, path: String, queryItems: [URLQueryItem] = []) async -> HTTPResponse {
        guard method == "GET" else {
            return error(.notFound, message: "Unsupported method \(method)", statusCode: 404)
        }

        switch path {
        case "/v1/incidents":
            return await incidents(queryItems: queryItems)
        case let incidentPath where incidentPath.hasPrefix("/v1/incidents/"):
            let id = String(incidentPath.dropFirst("/v1/incidents/".count)).removingPercentEncoding ?? ""
            return await incident(id: id)
        case "/v1/agencies":
            return await agencies()
        case "/v1/districts":
            return await districts()
        case "/v1/freshness":
            return await freshness()
        case "/v1/health":
            return await health()
        case "/v1/surge-alerts":
            return await surgeAlerts()
        case "/v1/surge-trends":
            return await surgeTrends(queryItems: queryItems)
        case "/v1/hazard-score":
            return await hazardScore()
        default:
            return error(.notFound, message: "Unknown endpoint \(path)", statusCode: 404)
        }
    }

    private func incidents(queryItems: [URLQueryItem]) async -> HTTPResponse {
        guard let snapshot = await store.currentSnapshot() else {
            return error(.sourceUnavailable, message: "No successful DataSF ingest is available yet.", statusCode: 503)
        }

        let filters = Dictionary(uniqueKeysWithValues: queryItems.compactMap { item in
            item.value.map { (item.name, $0) }
        })
        let filtered = snapshot.incidents.filter { incident in
            let matchesStatus = filters["status"] == nil || incident.status == filters["status"]
            let matchesAgency = filters["agencyType"] == nil || incident.agencyType == filters["agencyType"]
            let matchesDistrict = filters["districtId"] == nil || incident.districtId == filters["districtId"]
            return matchesStatus && matchesAgency && matchesDistrict
        }
        let limited = filters["limit"].flatMap(Int.init).map { Array(filtered.prefix(max(0, $0))) } ?? filtered

        return encodeEnvelope(data: limited, snapshot: snapshot)
    }

    private func incident(id: String) async -> HTTPResponse {
        guard let snapshot = await store.currentSnapshot() else {
            return error(.sourceUnavailable, message: "No successful DataSF ingest is available yet.", statusCode: 503)
        }
        guard let incident = snapshot.incidents.first(where: { $0.id == id }) else {
            return error(.notFound, message: "Incident \(id) was not found.", statusCode: 404)
        }
        return encodeEnvelope(data: incident, snapshot: snapshot)
    }

    private func agencies() async -> HTTPResponse {
        guard let snapshot = await store.currentSnapshot() else {
            return error(.sourceUnavailable, message: "No successful DataSF ingest is available yet.", statusCode: 503)
        }
        let agencies = Dictionary(grouping: snapshot.incidents, by: \.agencyId)
            .values
            .compactMap { incidents -> AgencyPayload? in
                guard let first = incidents.first else { return nil }
                return AgencyPayload(
                    id: first.agencyId,
                    name: first.agencyName,
                    type: first.agencyType,
                    activeIncidents: incidents.filter(\.isOperationallyActive).count,
                    totalIncidents: incidents.count
                )
            }
            .sorted { $0.name < $1.name }
        return encodeEnvelope(data: agencies, snapshot: snapshot)
    }

    private func districts() async -> HTTPResponse {
        guard let snapshot = await store.currentSnapshot() else {
            return error(.sourceUnavailable, message: "No successful DataSF ingest is available yet.", statusCode: 503)
        }
        let districts = Dictionary(grouping: snapshot.incidents, by: \.districtId)
            .values
            .compactMap { incidents -> DistrictPayload? in
                guard let first = incidents.first else { return nil }
                return DistrictPayload(
                    id: first.districtId,
                    name: first.districtName,
                    activeIncidents: incidents.filter(\.isOperationallyActive).count,
                    totalIncidents: incidents.count
                )
            }
            .sorted { $0.name < $1.name }
        return encodeEnvelope(data: districts, snapshot: snapshot)
    }

    private func freshness() async -> HTTPResponse {
        guard let snapshot = await store.currentSnapshot() else {
            return error(.sourceUnavailable, message: "No successful DataSF ingest is available yet.", statusCode: 503)
        }
        return encodeEnvelope(data: snapshot.freshness, snapshot: snapshot)
    }

    private func health() async -> HTTPResponse {
        let health = await store.health(checkedAt: now())
        let freshness = FreshnessMetadata(
            fetchedAt: now(),
            sourceDataAsOf: nil,
            sourceDataLoadedAt: nil,
            staleAfterSeconds: MeshBackendDefaults.staleAfterSeconds
        )
        return encodeEnvelope(data: health, freshness: freshness)
    }

    private func surgeAlerts() async -> HTTPResponse {
        guard let snapshot = await store.currentSnapshot() else {
            return error(.sourceUnavailable, message: "No successful DataSF ingest is available yet.", statusCode: 503)
        }
        let alerts = MeshDerivedSignals.deriveSurgeAlerts(incidents: snapshot.incidents, now: now())
        return encodeEnvelope(data: alerts, snapshot: snapshot)
    }

    private func surgeTrends(queryItems: [URLQueryItem]) async -> HTTPResponse {
        guard let snapshot = await store.currentSnapshot() else {
            return error(.sourceUnavailable, message: "No successful DataSF ingest is available yet.", statusCode: 503)
        }
        let filters = Dictionary(uniqueKeysWithValues: queryItems.compactMap { item in
            item.value.map { (item.name, $0) }
        })
        let districtId = filters["districtId"]
        let hours = filters["hours"].flatMap(Int.init) ?? 24
        let series = MeshDerivedSignals.deriveSurgeTrendSeries(
            incidents: snapshot.incidents,
            districtId: districtId,
            hours: max(1, hours),
            now: now()
        )
        return encodeEnvelope(data: series, snapshot: snapshot)
    }

    private func hazardScore() async -> HTTPResponse {
        guard let snapshot = await store.currentSnapshot() else {
            return error(.sourceUnavailable, message: "No successful DataSF ingest is available yet.", statusCode: 503)
        }
        let alerts = MeshDerivedSignals.deriveSurgeAlerts(incidents: snapshot.incidents, now: now())
        let hazard = MeshDerivedSignals.deriveHazardScore(
            incidents: snapshot.incidents,
            surgeAlerts: alerts,
            now: now()
        )
        return encodeEnvelope(data: hazard, snapshot: snapshot)
    }

    private func encodeEnvelope<Payload: Codable & Equatable>(data: Payload, snapshot: DataSFIncidentSnapshot) -> HTTPResponse {
        encodeEnvelope(data: data, freshness: snapshot.freshness)
    }

    private func encodeEnvelope<Payload: Codable & Equatable>(data: Payload, freshness: FreshnessMetadata) -> HTTPResponse {
        do {
            let envelope = APIEnvelope(
                data: data,
                source: MeshBackendContract.dataSFDispatchedCallsSource,
                freshness: freshness
            )
            return HTTPResponse(
                statusCode: 200,
                headers: ["Content-Type": "application/json"],
                body: try encoder.encode(envelope)
            )
        } catch {
            return self.error(.internalError, message: error.localizedDescription, statusCode: 500)
        }
    }

    private func error(_ code: APIErrorCode, message: String, statusCode: Int) -> HTTPResponse {
        let payload = APIErrorPayload(code: code, message: message, retryAfterSeconds: nil)
        let body = (try? encoder.encode(payload)) ?? Data()
        return HTTPResponse(statusCode: statusCode, headers: ["Content-Type": "application/json"], body: body)
    }
}

private extension IncidentPayload {
    var isOperationallyActive: Bool {
        status == "Active" || status == "Responding" || status == "On Scene"
    }
}
