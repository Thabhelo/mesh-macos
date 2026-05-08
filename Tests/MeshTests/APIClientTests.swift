import XCTest
@testable import Mesh

final class APIClientTests: XCTestCase {
    private let fetchedAt = Date(timeIntervalSince1970: 1_715_810_400)

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testFetchDataSFIncidentSnapshotBuildsQueryAndNormalizesIncident() async throws {
        let client = makeClient(statusCode: 200, body: dataSFResponse([
            dataSFCall(
                id: "240000001",
                priority: "A",
                agency: "Police",
                type: "TRAF COLLISION",
                policeDistrict: "SOUTHERN",
                closeDatetime: nil
            )
        ]))

        let result = try await client.fetchDataSFIncidentSnapshot(limit: 25)
        let request = try XCTUnwrap(MockURLProtocol.requests.first)
        let url = try XCTUnwrap(request.url)
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let queryItems = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) })

        XCTAssertEqual(url.scheme, "https")
        XCTAssertEqual(url.host, "example.test")
        XCTAssertEqual(queryItems["$limit"], "25")
        XCTAssertEqual(queryItems["$order"], "call_last_updated_at DESC")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), "Mesh macOS (San Francisco public-safety monitor)")

        XCTAssertEqual(result.fetchedAt, fetchedAt)
        XCTAssertEqual(result.incidents.count, 1)
        let incident = try XCTUnwrap(result.incidents.first)
        XCTAssertEqual(incident.id, "datasf:gnap-fj3t:240000001")
        XCTAssertEqual(incident.type, "Traffic Collision")
        XCTAssertEqual(incident.agencyName, "San Francisco Police Department")
        XCTAssertEqual(incident.agencyType, .police)
        XCTAssertEqual(incident.districtId, "southern")
        XCTAssertEqual(incident.districtName, "Southern")
        XCTAssertEqual(incident.status, .responding)
        XCTAssertEqual(incident.severity, .critical)
        XCTAssertEqual(incident.location.latitude, 37.7898, accuracy: 0.0001)
        XCTAssertEqual(incident.location.longitude, -122.3915, accuracy: 0.0001)
        XCTAssertEqual(result.sourceDataAsOf, dataSFDate("2024-05-15T12:03:00.000"))
        XCTAssertEqual(result.sourceDataLoadedAt, dataSFDate("2024-05-15T12:04:00.000"))
    }

    func testFetchIncidentsAppliesStatusAgencyAndDistrictFilters() async throws {
        let client = makeClient(statusCode: 200, body: backendEnvelope([
            backendIncident(id: "a", status: "Responding", agencyType: "Police", districtId: "southern"),
            backendIncident(id: "b", type: "Transit Delay", status: "Responding", agencyType: "Transit", districtId: "central"),
            backendIncident(id: "c", type: "Assault", status: "Closed", agencyType: "Police", districtId: "southern")
        ]))

        let incidents = try await client.fetchIncidents(
            status: .responding,
            agencyType: .police,
            districtId: "southern"
        )

        XCTAssertEqual(incidents.map(\.id), ["datasf:gnap-fj3t:a"])
    }

    func testFetchIncidentSnapshotBuildsBackendQueryAndMapsEnvelope() async throws {
        let client = makeClient(statusCode: 200, body: backendEnvelope([
            backendIncident(id: "backend", status: "On Scene", agencyType: "Fire", districtId: "mission")
        ]))

        let result = try await client.fetchIncidentSnapshot(limit: 25)
        let request = try XCTUnwrap(MockURLProtocol.requests.first)
        let url = try XCTUnwrap(request.url)
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let queryItems = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) })
        let incident = try XCTUnwrap(result.incidents.first)

        XCTAssertEqual(url.path, "/v1/incidents")
        XCTAssertEqual(queryItems["regionId"], "san-francisco")
        XCTAssertEqual(queryItems["limit"], "25")
        XCTAssertEqual(incident.id, "datasf:gnap-fj3t:backend")
        XCTAssertEqual(incident.status, .onScene)
        XCTAssertEqual(incident.agencyType, .fire)
        XCTAssertEqual(result.sourceDataAsOf, isoDate("2024-05-15T12:03:00Z"))
    }

    func testFetchIncidentSnapshotFallsBackToDataSFWhenBackendIsUnavailable() async throws {
        MockURLProtocol.enqueue(statusCode: 503, body: #"{"error":"backend unavailable"}"#)
        MockURLProtocol.enqueue(statusCode: 200, body: dataSFResponse([
            dataSFCall(id: "fallback", priority: "A", agency: "Police", type: "TRAF COLLISION", policeDistrict: "SOUTHERN", closeDatetime: nil)
        ]))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let client = APIClient(
            baseURL: URL(string: "https://api.example.test/v1")!,
            dataSFIncidentsURL: URL(string: "https://data.example.test/resource/gnap-fj3t.json")!,
            session: session,
            now: { self.fetchedAt }
        )

        let snapshot = try await client.fetchIncidentSnapshotWithSource(limit: 25)

        XCTAssertEqual(snapshot.dataSource, .dataSFDevelopmentFallback)
        XCTAssertEqual(snapshot.fetchResult.incidents.map(\.id), ["datasf:gnap-fj3t:fallback"])
        XCTAssertNotNil(snapshot.fallbackReason)
        XCTAssertEqual(MockURLProtocol.requests.map { $0.url?.host }, ["api.example.test", "data.example.test"])
    }

    func testFetchIncidentSnapshotUsesDataSFWhenBackendURLIsNotConfigured() async throws {
        let client = makeClient(
            statusCode: 200,
            body: dataSFResponse([
                dataSFCall(id: "direct", priority: "A", agency: "Police", type: "TRAF COLLISION", policeDistrict: "SOUTHERN", closeDatetime: nil)
            ]),
            baseURL: nil
        )

        let snapshot = try await client.fetchIncidentSnapshotWithSource(limit: 25)

        XCTAssertEqual(snapshot.dataSource, .dataSFDevelopmentFallback)
        XCTAssertEqual(snapshot.fallbackReason, "Mesh backend URL is not configured.")
        XCTAssertEqual(snapshot.fetchResult.incidents.map(\.id), ["datasf:gnap-fj3t:direct"])
        XCTAssertEqual(MockURLProtocol.requests.map { $0.url?.path }, ["/resource/gnap-fj3t.json"])
    }

    func testFetchAgenciesAndDistrictsDoNotReturnSampleFallbacks() async throws {
        let client = APIClient(dataSFIncidentsURL: URL(string: "https://example.test/resource/gnap-fj3t.json")!)

        let agencies = try await client.fetchAgencies()
        let districts = try await client.fetchDistricts()

        XCTAssertTrue(agencies.isEmpty)
        XCTAssertTrue(districts.isEmpty)
    }

    func testFetchDataSFIncidentSnapshotMapsFireAndTransitAgencies() async throws {
        let client = makeClient(statusCode: 200, body: dataSFResponse([
            dataSFCall(id: "fire", priority: "B", agency: "Fire", type: "VEH FIRE", policeDistrict: "MISSION", closeDatetime: nil),
            dataSFCall(id: "transit", priority: "C", agency: "MTA", type: "TRANSIT DELAY", policeDistrict: "CENTRAL", closeDatetime: nil)
        ]))

        let incidents = try await client.fetchDataSFIncidentSnapshot().incidents
        let incidentsById = Dictionary(uniqueKeysWithValues: incidents.map { ($0.id, $0) })
        let fireIncident = try XCTUnwrap(incidentsById["datasf:gnap-fj3t:fire"])
        let transitIncident = try XCTUnwrap(incidentsById["datasf:gnap-fj3t:transit"])

        XCTAssertEqual(fireIncident.agencyType, .fire)
        XCTAssertEqual(fireIncident.agencyName, "San Francisco Fire Department")
        XCTAssertEqual(transitIncident.agencyType, .transit)
        XCTAssertEqual(transitIncident.agencyName, "San Francisco Municipal Transportation Agency")
    }

    func testFetchDataSFIncidentSnapshotMapsHTTPAndDecodingErrors() async throws {
        let serverClient = makeClient(statusCode: 503, body: #"{"error":"down"}"#)

        do {
            _ = try await serverClient.fetchDataSFIncidentSnapshot()
            XCTFail("Expected server error")
        } catch APIError.serverError(let statusCode, let message) {
            XCTAssertEqual(statusCode, 503)
            XCTAssertEqual(message, #"{"error":"down"}"#)
        }

        MockURLProtocol.reset()
        let decodingClient = makeClient(statusCode: 200, body: #"{"not":"an array"}"#)

        do {
            _ = try await decodingClient.fetchDataSFIncidentSnapshot()
            XCTFail("Expected decoding error")
        } catch APIError.decodingError {
            // Expected.
        }
    }

    func testFetchDataSFIncidentSnapshotDropsRowsMissingRequiredFields() async throws {
        let client = makeClient(statusCode: 200, body: dataSFResponse([
            dataSFCall(id: "", priority: "A", agency: "Police", type: "TRAF COLLISION", policeDistrict: "SOUTHERN", closeDatetime: nil),
            dataSFCall(id: "missing-point", priority: "A", agency: "Police", type: "TRAF COLLISION", policeDistrict: "SOUTHERN", closeDatetime: nil, includePoint: false),
            dataSFCall(id: "valid", priority: "A", agency: "Police", type: "TRAF COLLISION", policeDistrict: "SOUTHERN", closeDatetime: nil)
        ]))

        let result = try await client.fetchDataSFIncidentSnapshot()

        XCTAssertEqual(result.incidents.map(\.id), ["datasf:gnap-fj3t:valid"])
    }

    private func makeClient(
        statusCode: Int,
        body: String,
        baseURL: URL? = URL(string: "https://example.test/v1")!
    ) -> APIClient {
        MockURLProtocol.enqueue(statusCode: statusCode, body: body)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        return APIClient(
            baseURL: baseURL,
            dataSFIncidentsURL: URL(string: "https://example.test/resource/gnap-fj3t.json")!,
            session: session,
            now: { self.fetchedAt }
        )
    }

    private func dataSFResponse(_ calls: [String]) -> String {
        "[\(calls.joined(separator: ","))]"
    }

    private func backendEnvelope(_ incidents: [String]) -> String {
        """
        {
          "apiVersion": "v1",
          "regionId": "san-francisco",
          "regionName": "San Francisco",
          "data": [\(incidents.joined(separator: ","))],
          "source": {
            "name": "DataSF Dispatched Calls",
            "datasetIdentifier": "gnap-fj3t",
            "url": "https://data.sfgov.org/resource/gnap-fj3t.json"
          },
          "freshness": {
            "fetchedAt": "2024-05-15T12:05:00Z",
            "sourceDataAsOf": "2024-05-15T12:03:00Z",
            "sourceDataLoadedAt": "2024-05-15T12:04:00Z",
            "staleAfterSeconds": 900
          }
        }
        """
    }

    private func backendIncident(
        id: String,
        type: String = "Traffic Collision",
        status: String,
        agencyType: String,
        districtId: String
    ) -> String {
        """
        {
          "id": "datasf:gnap-fj3t:\(id)",
          "type": "\(type)",
          "description": "\(type) | Priority A",
          "agencyType": "\(agencyType)",
          "agencyId": "agency-\(id)",
          "agencyName": "San Francisco \(agencyType)",
          "districtId": "\(districtId)",
          "districtName": "\(districtId.capitalized)",
          "status": "\(status)",
          "severity": 4,
          "location": {"latitude": 37.7898, "longitude": -122.3915},
          "address": "I-80 W at 5th St",
          "reportedAt": "2024-05-15T12:00:00Z",
          "updatedAt": "2024-05-15T12:03:00Z",
          "respondingUnits": [],
          "notes": []
        }
        """
    }

    private func dataSFCall(
        id: String,
        priority: String,
        agency: String,
        type: String,
        policeDistrict: String,
        closeDatetime: String?,
        includePoint: Bool = true
    ) -> String {
        let closeValue = closeDatetime.map { #""\#($0)""# } ?? "null"
        let pointValue = includePoint
            ? #"{"type":"Point","coordinates":[-122.3915,37.7898]}"#
            : "null"

        return """
        {
          "id": "\(id)",
          "cad_number": "CAD-\(id)",
          "received_datetime": "2024-05-15T12:00:00.000",
          "entry_datetime": "2024-05-15T12:01:00.000",
          "dispatch_datetime": "2024-05-15T12:02:00.000",
          "enroute_datetime": null,
          "onscene_datetime": null,
          "close_datetime": \(closeValue),
          "call_type_original_desc": "\(type)",
          "call_type_final_desc": "\(type)",
          "priority_original": "\(priority)",
          "priority_final": "\(priority)",
          "agency": "\(agency)",
          "disposition": "REP",
          "sensitive_call": false,
          "intersection_name": "I-80 W at 5th St",
          "intersection_point": \(pointValue),
          "supervisor_district": "6",
          "analysis_neighborhood": "South of Market",
          "police_district": "\(policeDistrict)",
          "call_last_updated_at": "2024-05-15T12:03:00.000",
          "data_as_of": "2024-05-15T12:03:00.000",
          "data_loaded_at": "2024-05-15T12:04:00.000"
        }
        """
    }

    private func dataSFDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        return formatter.date(from: value)
    }

    private func isoDate(_ value: String) -> Date? {
        ISO8601DateFormatter().date(from: value)
    }
}

private final class MockURLProtocol: URLProtocol {
    struct Response {
        let statusCode: Int
        let body: Data
    }

    private static var responses: [Response] = []
    private(set) static var requests: [URLRequest] = []

    static func enqueue(statusCode: Int, body: String) {
        responses.append(Response(statusCode: statusCode, body: Data(body.utf8)))
    }

    static func reset() {
        responses = []
        requests = []
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.requests.append(request)
        let response = Self.responses.isEmpty
            ? Response(statusCode: 500, body: Data())
            : Self.responses.removeFirst()
        let httpResponse = HTTPURLResponse(
            url: request.url!,
            statusCode: response.statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!

        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: response.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
