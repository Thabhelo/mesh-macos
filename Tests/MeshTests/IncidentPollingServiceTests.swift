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
            (firstFetchAt, dataSFResponse([
                dataSFCall(id: "one", priority: "B", updatedAt: "2024-05-15T12:02:00.000", closeDatetime: nil),
                dataSFCall(id: "two", priority: "C", updatedAt: "2024-05-15T12:03:00.000", closeDatetime: nil)
            ])),
            (secondFetchAt, dataSFResponse([
                dataSFCall(id: "one", priority: "A", updatedAt: "2024-05-15T12:10:00.000", closeDatetime: nil),
                dataSFCall(id: "three", priority: "B", updatedAt: "2024-05-15T12:11:00.000", closeDatetime: nil)
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
            (firstFetchAt, dataSFResponse([
                dataSFCall(id: "one", priority: "B", updatedAt: "2024-05-15T12:02:00.000", closeDatetime: nil)
            ])),
            (secondFetchAt, dataSFResponse([
                dataSFCall(id: "one", priority: "B", updatedAt: "2024-05-15T12:02:00.000", closeDatetime: nil)
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

    private func dataSFResponse(_ calls: [String]) -> String {
        "[\(calls.joined(separator: ","))]"
    }

    private func dataSFCall(
        id: String,
        priority: String,
        updatedAt: String,
        closeDatetime: String?
    ) -> String {
        let closeValue = closeDatetime.map { #""\#($0)""# } ?? "null"
        return """
        {
          "id": "\(id)",
          "received_datetime": "2024-05-15T12:00:00.000",
          "entry_datetime": "2024-05-15T12:01:00.000",
          "dispatch_datetime": "2024-05-15T12:02:00.000",
          "enroute_datetime": null,
          "onscene_datetime": null,
          "close_datetime": \(closeValue),
          "call_type_original_desc": "ASSAULT",
          "call_type_final_desc": "ASSAULT",
          "priority_original": "\(priority)",
          "priority_final": "\(priority)",
          "agency": "Police",
          "disposition": "REP",
          "sensitive_call": false,
          "intersection_name": "5th St & Mission St",
          "intersection_point": {"type":"Point","coordinates":[-122.4010,37.7840]},
          "analysis_neighborhood": "South of Market",
          "police_district": "SOUTHERN",
          "call_last_updated_at": "\(updatedAt)",
          "data_as_of": "\(updatedAt)",
          "data_loaded_at": "\(updatedAt)"
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
