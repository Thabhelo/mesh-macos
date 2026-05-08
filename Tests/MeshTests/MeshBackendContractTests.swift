import XCTest
@testable import MeshBackendCore

final class MeshBackendContractTests: XCTestCase {
    func testBackendContractDefinesRequiredVersionedEndpoints() {
        let endpointPaths = Set(MeshBackendContract.endpoints.map(\.path))

        XCTAssertEqual(MeshBackendContract.apiVersion, "v1")
        XCTAssertEqual(MeshBackendContract.basePath, "/v1")
        XCTAssertEqual(MeshBackendContract.supportedRegionId, "san-francisco")
        XCTAssertTrue(MeshBackendContract.pollingSnapshotFirst)
        XCTAssertTrue(endpointPaths.isSuperset(of: [
            "/v1/incidents",
            "/v1/incidents/{id}",
            "/v1/agencies",
            "/v1/districts",
            "/v1/surge-alerts",
            "/v1/surge-trends",
            "/v1/hazard-score",
            "/v1/freshness",
            "/v1/health"
        ]))
    }

    func testEnvelopeCarriesSourceAttributionAndFreshness() throws {
        let fetchedAt = Date(timeIntervalSince1970: 1_715_810_400)
        let sourceDataAsOf = fetchedAt.addingTimeInterval(-60)
        let freshness = FreshnessMetadata(
            fetchedAt: fetchedAt,
            sourceDataAsOf: sourceDataAsOf,
            sourceDataLoadedAt: fetchedAt.addingTimeInterval(-30),
            staleAfterSeconds: 900
        )
        let envelope = APIEnvelope(
            data: [String](),
            source: MeshBackendContract.dataSFDispatchedCallsSource,
            freshness: freshness
        )

        XCTAssertEqual(envelope.apiVersion, "v1")
        XCTAssertEqual(envelope.regionId, "san-francisco")
        XCTAssertEqual(envelope.source.datasetIdentifier, "gnap-fj3t")
        XCTAssertFalse(envelope.freshness.isStale(relativeTo: sourceDataAsOf.addingTimeInterval(899)))
        XCTAssertTrue(envelope.freshness.isStale(relativeTo: sourceDataAsOf.addingTimeInterval(901)))

        let encoded = try JSONEncoder().encode(envelope)
        let decoded = try JSONDecoder().decode(APIEnvelope<[String]>.self, from: encoded)
        XCTAssertEqual(decoded, envelope)
    }

    func testServiceSkeletonUsesDataSFAsPrimarySource() {
        let skeleton = MeshBackendServiceSkeleton()

        XCTAssertEqual(skeleton.apiVersion, "v1")
        XCTAssertEqual(skeleton.primarySource.name, "DataSF Dispatched Calls")
        XCTAssertEqual(skeleton.primarySource.datasetIdentifier, "gnap-fj3t")
        XCTAssertTrue(skeleton.supportsPollingSnapshots)
        XCTAssertEqual(skeleton.endpoints.count, MeshBackendContract.endpoints.count)
    }

    func testDataSFNormalizerBuildsBackendIncidentPayloadAndFreshness() throws {
        let fetchedAt = Date(timeIntervalSince1970: 1_715_810_400)
        let snapshot = try DataSFNormalizer.snapshot(
            from: Data(dataSFResponse().utf8),
            fetchedAt: fetchedAt
        )
        let incident = try XCTUnwrap(snapshot.incidents.first)

        XCTAssertEqual(snapshot.incidents.count, 1)
        XCTAssertEqual(incident.id, "datasf:gnap-fj3t:240000001")
        XCTAssertEqual(incident.type, "Traffic Collision")
        XCTAssertEqual(incident.status, "Responding")
        XCTAssertEqual(incident.severity, 4)
        XCTAssertEqual(incident.address, "I-80 W at 5th St")
        XCTAssertEqual(incident.sourceDistrictTuple, "southern:Southern")
        XCTAssertEqual(snapshot.sourceDataAsOf, DataSFNormalizer.parseDataSFDate("2024-05-15T12:03:00.000"))
    }

    func testBackendRouterServesIncidentEnvelopeAndHealth() async throws {
        let fetchedAt = Date(timeIntervalSince1970: 1_715_810_400)
        let snapshot = try DataSFNormalizer.snapshot(from: Data(dataSFResponse().utf8), fetchedAt: fetchedAt)
        let store = MeshBackendStore(snapshot: snapshot)
        let router = MeshBackendRouter(store: store, now: { fetchedAt })

        let incidentsResponse = await router.route(method: "GET", path: "/v1/incidents")
        let healthResponse = await router.route(method: "GET", path: "/v1/health")

        XCTAssertEqual(incidentsResponse.statusCode, 200)
        XCTAssertEqual(healthResponse.statusCode, 200)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let incidentsEnvelope = try decoder.decode(APIEnvelope<[IncidentPayload]>.self, from: incidentsResponse.body)
        let healthEnvelope = try decoder.decode(APIEnvelope<BackendHealthPayload>.self, from: healthResponse.body)

        XCTAssertEqual(incidentsEnvelope.data.map(\.id), ["datasf:gnap-fj3t:240000001"])
        XCTAssertEqual(healthEnvelope.data.status, .healthy)
        XCTAssertEqual(healthEnvelope.data.sources.first?.lastSuccessfulIngestAt, fetchedAt)
    }

    func testBackendRouterServesDerivedMetadataEndpoints() async throws {
        let fetchedAt = Date(timeIntervalSince1970: 1_715_810_400)
        let snapshot = try DataSFNormalizer.snapshot(from: Data(dataSFResponse().utf8), fetchedAt: fetchedAt)
        let router = MeshBackendRouter(store: MeshBackendStore(snapshot: snapshot), now: { fetchedAt })

        let agenciesResponse = await router.route(method: "GET", path: "/v1/agencies")
        let districtsResponse = await router.route(method: "GET", path: "/v1/districts")

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let agenciesEnvelope = try decoder.decode(APIEnvelope<[AgencyPayload]>.self, from: agenciesResponse.body)
        let districtsEnvelope = try decoder.decode(APIEnvelope<[DistrictPayload]>.self, from: districtsResponse.body)

        XCTAssertEqual(agenciesEnvelope.data.first?.name, "San Francisco Police Department")
        XCTAssertEqual(agenciesEnvelope.data.first?.activeIncidents, 1)
        XCTAssertEqual(districtsEnvelope.data.first?.id, "southern")
        XCTAssertEqual(districtsEnvelope.data.first?.activeIncidents, 1)
    }

    func testBackendStorePersistsAndReloadsSnapshot() async throws {
        let persistenceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("incidents.json")
        defer {
            try? FileManager.default.removeItem(at: persistenceURL.deletingLastPathComponent())
        }

        let fetchedAt = Date(timeIntervalSince1970: 1_715_810_400)
        let snapshot = try DataSFNormalizer.snapshot(from: Data(dataSFResponse().utf8), fetchedAt: fetchedAt)
        let writingStore = MeshBackendStore(persistenceURL: persistenceURL)
        await writingStore.ingest(snapshot)

        let reloadedStore = MeshBackendStore(persistenceURL: persistenceURL)
        let reloadedSnapshot = await reloadedStore.currentSnapshot()

        XCTAssertEqual(reloadedSnapshot?.incidents.map(\.id), ["datasf:gnap-fj3t:240000001"])
        XCTAssertEqual(reloadedSnapshot?.fetchedAt, fetchedAt)
    }

    func testOpenAPIContractDocumentsRequiredEndpointsAndMetadata() throws {
        let contractURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Backend/openapi/mesh-api-v1.yaml")
        let contract = try String(contentsOf: contractURL, encoding: .utf8)

        for path in MeshBackendContract.endpoints.map(\.path) {
            let openAPIPath = path.replacingOccurrences(of: "/v1", with: "")
            XCTAssertTrue(contract.contains("  \(openAPIPath):"), "Missing \(openAPIPath) in OpenAPI contract")
        }

        XCTAssertTrue(contract.contains("apiVersion"))
        XCTAssertTrue(contract.contains("SourceAttribution"))
        XCTAssertTrue(contract.contains("FreshnessMetadata"))
        XCTAssertTrue(contract.contains("gnap-fj3t"))
    }

    private func dataSFResponse() -> String {
        """
        [
          {
            "id": "240000001",
            "received_datetime": "2024-05-15T12:00:00.000",
            "entry_datetime": "2024-05-15T12:01:00.000",
            "dispatch_datetime": "2024-05-15T12:02:00.000",
            "close_datetime": null,
            "call_type_original_desc": "TRAF COLLISION",
            "call_type_final_desc": "TRAF COLLISION",
            "priority_original": "A",
            "priority_final": "A",
            "agency": "Police",
            "disposition": "REP",
            "sensitive_call": false,
            "intersection_name": "I-80 W AT 5TH ST",
            "intersection_point": {"type":"Point","coordinates":[-122.3915,37.7898]},
            "analysis_neighborhood": "South of Market",
            "police_district": "SOUTHERN",
            "call_last_updated_at": "2024-05-15T12:03:00.000",
            "data_as_of": "2024-05-15T12:03:00.000",
            "data_loaded_at": "2024-05-15T12:04:00.000"
          }
        ]
        """
    }
}

private extension IncidentPayload {
    var sourceDistrictTuple: String {
        "\(districtId):\(districtName)"
    }
}
