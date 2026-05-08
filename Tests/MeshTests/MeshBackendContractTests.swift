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

    func testOpenAPIContractDocumentsRequiredEndpointsAndMetadata() throws {
        let contractURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
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
}
