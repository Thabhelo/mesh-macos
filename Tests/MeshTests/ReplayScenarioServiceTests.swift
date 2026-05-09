import XCTest
@testable import MeshAppSPM

final class ReplayScenarioServiceTests: XCTestCase {
    private let anchorDate = Date(timeIntervalSince1970: 1_715_810_400)

    func testReplayFramesProgressThroughRepeatableOperationalScenario() {
        let firstRun = ReplayScenarioService.frames(anchorDate: anchorDate)
        let secondRun = ReplayScenarioService.frames(anchorDate: anchorDate)

        XCTAssertEqual(firstRun.count, 5)
        XCTAssertEqual(firstRun.map(\.id), secondRun.map(\.id))
        XCTAssertEqual(firstRun.map(\.timestamp), secondRun.map(\.timestamp))
        XCTAssertEqual(firstRun.map { $0.incidents.map(\.id) }, secondRun.map { $0.incidents.map(\.id) })
        XCTAssertEqual(firstRun.map(\.stepNumber), [1, 2, 3, 4, 5])
        XCTAssertEqual(firstRun.map(\.incidents.count), [2, 4, 6, 8, 8])
    }

    func testReplayScenarioCreatesSouthernDistrictSurgeAndHazardDecisionPoint() throws {
        let frames = ReplayScenarioService.frames(anchorDate: anchorDate)
        let peakFrame = try XCTUnwrap(frames.first { $0.id == "hazard-peak" })

        let alerts = OperationalIntelligenceService.deriveSurgeAlerts(
            incidents: peakFrame.incidents,
            districts: District.samples,
            now: peakFrame.timestamp
        )
        let hazard = OperationalIntelligenceService.deriveHazardScore(
            incidents: peakFrame.incidents,
            districts: District.samples,
            surgeAlerts: alerts,
            now: peakFrame.timestamp
        )

        XCTAssertEqual(alerts.first?.districtId, "D-03")
        XCTAssertGreaterThanOrEqual(alerts.first?.severity ?? .normal, .high)
        XCTAssertEqual(hazard.districtScores.first?.districtId, "D-03")
        XCTAssertEqual(hazard.districtScores.first?.primaryRisk, "Call Surge")
        XCTAssertTrue(peakFrame.recommendedAction.localizedCaseInsensitiveContains("Southern District"))
        XCTAssertTrue(peakFrame.evidence.contains { $0.localizedCaseInsensitiveContains("surge") })
    }

    func testReplayFrameUsesIncidentPollingResultContract() throws {
        let frame = try XCTUnwrap(ReplayScenarioService.frames(anchorDate: anchorDate).first)
        let result = frame.incidentResult

        XCTAssertEqual(result.incidents, frame.incidents)
        XCTAssertEqual(result.refreshedAt, frame.timestamp)
        XCTAssertEqual(result.sourceDataAsOf, frame.timestamp)
        XCTAssertEqual(result.sourceDataLoadedAt, frame.timestamp)
        XCTAssertEqual(result.updates.count, frame.incidents.count)
        XCTAssertTrue(result.updates.allSatisfy { $0.type == .new })
    }
}
