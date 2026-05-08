import XCTest
@testable import Mesh

final class AppStatePresentationTests: XCTestCase {
    func testConnectionStatusDetailIncludesErrorBeforeRecoverySuggestion() {
        let detail = ConnectionStatusDetailFormatter.detailText(
            dataMode: .live,
            connectionState: .error,
            error: "DataSF Dispatched Calls rate-limited the request.",
            recoverySuggestion: "Wait a minute before retrying.",
            lastIncidentRefreshAt: nil
        )

        XCTAssertEqual(detail, "DataSF Dispatched Calls rate-limited the request. Wait a minute before retrying.")
    }

    func testDerivedAgenciesUseAllIncidentsForTotalUnits() throws {
        let incidents = [
            makeIncident(id: "active", status: .active),
            makeIncident(id: "closed", status: .closed)
        ]

        let agency = try XCTUnwrap(OperationalMetadataBuilder.deriveAgencies(from: incidents).first)

        XCTAssertEqual(agency.activeUnits, 1)
        XCTAssertEqual(agency.totalUnits, 2)
        XCTAssertEqual(agency.availableUnits, 1)
        XCTAssertEqual(agency.utilizationPercentage, 50)
    }

    private func makeIncident(id: String, status: IncidentStatus) -> Incident {
        let timestamp = Date(timeIntervalSince1970: 1_715_810_400)
        return Incident(
            id: id,
            type: "Traffic Collision",
            description: "Live San Francisco incident",
            agencyType: .police,
            agencyId: "san-francisco-police-department",
            agencyName: "San Francisco Police Department",
            districtId: "southern",
            districtName: "Southern",
            status: status,
            severity: .medium,
            location: .init(latitude: 37.7898, longitude: -122.3915),
            address: "I-80 W at 5th St",
            reportedAt: timestamp,
            updatedAt: timestamp,
            respondingUnits: [],
            notes: nil
        )
    }
}
