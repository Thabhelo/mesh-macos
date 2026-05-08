import XCTest
@testable import Mesh

final class IncidentPollingServiceTests: XCTestCase {
    private let firstFetchAt = Date(timeIntervalSince1970: 1_715_810_400)
    private let secondFetchAt = Date(timeIntervalSince1970: 1_715_810_700)

    override func tearDown() {
        PollingMockURLProtocol.reset()
        super.tearDown()
    }

    func testPollDiffsNewUpdatedAndClosedIncidentsWithFreshnessMetadata() async throws {
        let client = makeClient(responses: [
            (firstFetchAt, backendEnvelope(fetchedAt: "2024-05-15T15:00:00-07:00", incidents: [
                backendIncident(id: "one", severity: 3, updatedAt: "2024-05-15T12:02:00-07:00", status: "Responding"),
                backendIncident(id: "two", severity: 2, updatedAt: "2024-05-15T12:03:00-07:00", status: "Responding")
            ])),
            (secondFetchAt, backendEnvelope(fetchedAt: "2024-05-15T15:05:00-07:00", incidents: [
                backendIncident(id: "one", severity: 4, updatedAt: "2024-05-15T12:10:00-07:00", status: "Responding"),
                backendIncident(id: "three", severity: 3, updatedAt: "2024-05-15T12:11:00-07:00", status: "Responding")
            ]))
        ])
        let service = IncidentPollingService(apiClient: client)

        let first = try await service.poll(limit: 10)
        XCTAssertEqual(first.refreshedAt, firstFetchAt)
        XCTAssertEqual(first.sourceDataAsOf, dataSFDate("2024-05-15T12:03:00.000"))
        XCTAssertEqual(first.updates.map(\.type), [.new, .new])
        XCTAssertEqual(Set(first.incidents.map(\.id)), ["datasf:gnap-fj3t:one", "datasf:gnap-fj3t:two"])

        let second = try await service.poll(limit: 10)
        let updateTypesById = Dictionary(uniqueKeysWithValues: second.updates.map { ($0.incidentId ?? "", $0.type) })
        let closedIncident = try XCTUnwrap(second.incidents.first { $0.id == "datasf:gnap-fj3t:two" })

        XCTAssertEqual(second.refreshedAt, secondFetchAt)
        XCTAssertEqual(updateTypesById["datasf:gnap-fj3t:one"], .updated)
        XCTAssertEqual(updateTypesById["datasf:gnap-fj3t:two"], .closed)
        XCTAssertEqual(updateTypesById["datasf:gnap-fj3t:three"], .new)
        XCTAssertEqual(closedIncident.status, .closed)
    }

    func testResetClearsPollingSnapshot() async throws {
        let client = makeClient(responses: [
            (firstFetchAt, backendEnvelope(fetchedAt: "2024-05-15T15:00:00-07:00", incidents: [
                backendIncident(id: "one", severity: 3, updatedAt: "2024-05-15T12:02:00-07:00", status: "Responding")
            ])),
            (secondFetchAt, backendEnvelope(fetchedAt: "2024-05-15T15:05:00-07:00", incidents: [
                backendIncident(id: "one", severity: 3, updatedAt: "2024-05-15T12:02:00-07:00", status: "Responding")
            ]))
        ])
        let service = IncidentPollingService(apiClient: client)

        _ = try await service.poll()
        await service.reset()
        let afterReset = try await service.poll()

        XCTAssertEqual(afterReset.updates.map(\.type), [.new])
    }

    private func makeClient(responses: [(Date, String)]) -> APIClient {
        for (date, body) in responses {
            PollingMockURLProtocol.enqueue(statusCode: 200, body: body)
            PollingMockURLProtocol.fetchDates.append(date)
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PollingMockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        return APIClient(
            dataSFIncidentsURL: URL(string: "https://example.test/resource/gnap-fj3t.json")!,
            session: session,
            now: { PollingMockURLProtocol.fetchDates.removeFirst() }
        )
    }

    private func backendEnvelope(fetchedAt: String, incidents: [String]) -> String {
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
            "fetchedAt": "\(fetchedAt)",
            "sourceDataAsOf": "2024-05-15T12:03:00-07:00",
            "sourceDataLoadedAt": "2024-05-15T12:03:00-07:00",
            "staleAfterSeconds": 900
          }
        }
        """
    }

    private func backendIncident(
        id: String,
        severity: Int,
        updatedAt: String,
        status: String
    ) -> String {
        return """
        {
          "id": "datasf:gnap-fj3t:\(id)",
          "type": "Assault",
          "description": "Assault | Priority B",
          "agencyType": "Police",
          "agencyId": "san-francisco-police-department",
          "agencyName": "San Francisco Police Department",
          "districtId": "southern",
          "districtName": "Southern",
          "status": "\(status)",
          "severity": \(severity),
          "location": {"latitude": 37.7840, "longitude": -122.4010},
          "address": "5th St & Mission St",
          "reportedAt": "2024-05-15T12:00:00-07:00",
          "updatedAt": "\(updatedAt)",
          "respondingUnits": [],
          "notes": []
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
}

private final class PollingMockURLProtocol: URLProtocol {
    struct Response {
        let statusCode: Int
        let body: Data
    }

    static var fetchDates: [Date] = []
    private static var responses: [Response] = []

    static func enqueue(statusCode: Int, body: String) {
        responses.append(Response(statusCode: statusCode, body: Data(body.utf8)))
    }

    static func reset() {
        fetchDates = []
        responses = []
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
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
