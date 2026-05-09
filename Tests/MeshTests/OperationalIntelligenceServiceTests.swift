import XCTest
@testable import MeshAppSPM

final class OperationalIntelligenceServiceTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_715_810_400) // 2024-05-15 20:00:00 UTC

    func testDeriveSurgeAlertsPromotesCriticalActiveClusters() throws {
        let districts = [
            makeDistrict(id: "D-LOW", name: "Low Baseline District"),
            makeDistrict(id: "D-QUIET", name: "Quiet District")
        ]
        let incidents = [
            makeIncident(id: "critical-1", district: districts[0], severity: .critical, type: "Structure Fire", reportedMinutesAgo: 15),
            makeIncident(id: "critical-2", district: districts[0], severity: .critical, type: "Gas Leak", reportedMinutesAgo: 25),
            makeIncident(id: "critical-3", district: districts[0], severity: .critical, type: "Medical Emergency", reportedMinutesAgo: 35),
            makeIncident(id: "quiet-1", district: districts[1], severity: .medium, type: "Medical Emergency", reportedMinutesAgo: 20)
        ]

        let alerts = OperationalIntelligenceService.deriveSurgeAlerts(
            incidents: incidents,
            districts: districts,
            now: now
        )

        XCTAssertEqual(alerts.map(\.districtId), ["D-LOW"])
        let alert = try XCTUnwrap(alerts.first)
        XCTAssertEqual(alert.severity, .critical)
        XCTAssertEqual(alert.currentCallVolume, 3)
        XCTAssertLessThan(alert.expectedCallVolume, alert.currentCallVolume)
        XCTAssertEqual(alert.trend, .rising)
        XCTAssertNotNil(alert.predictedPeakTime)
        XCTAssertTrue(alert.contributingFactors.contains("3 critical-priority incidents"))
    }

    func testDeriveSurgeTrendDataIsDeterministicAndBucketed() {
        let district = makeDistrict(id: "D-TREND", name: "Trend District")
        let incidents = [
            makeIncident(id: "recent", district: district, reportedMinutesAgo: 20),
            makeIncident(id: "older", district: district, reportedMinutesAgo: 50),
            makeIncident(id: "outside-window", district: district, reportedMinutesAgo: 90)
        ]

        let first = OperationalIntelligenceService.deriveSurgeTrendData(
            incidents: incidents,
            districts: [district],
            districtId: district.id,
            hours: 1,
            now: now
        )
        let second = OperationalIntelligenceService.deriveSurgeTrendData(
            incidents: incidents,
            districts: [district],
            districtId: district.id,
            hours: 1,
            now: now
        )

        XCTAssertEqual(first.count, 4)
        XCTAssertEqual(first.map(\.callVolume).reduce(0, +), 2)
        XCTAssertEqual(first.map(\.id), second.map(\.id))
        XCTAssertEqual(first.map(\.timestamp), second.map(\.timestamp))
        XCTAssertEqual(first.map(\.callVolume), second.map(\.callVolume))
        XCTAssertEqual(first.map(\.expectedVolume), second.map(\.expectedVolume))
    }

    func testSurgeAlertsAreRankedBySeverityThenPercentageIncrease() {
        let smallerCritical = makeDistrict(id: "D-CRITICAL-A", name: "Critical A District")
        let largerCritical = makeDistrict(id: "D-CRITICAL-B", name: "Critical B District")
        let incidents =
            (0..<3).map {
                makeIncident(id: "a-\($0)", district: smallerCritical, severity: .critical, reportedMinutesAgo: TimeInterval(10 + $0))
            } +
            (0..<5).map {
                makeIncident(id: "b-\($0)", district: largerCritical, severity: .critical, reportedMinutesAgo: TimeInterval(10 + $0))
            }

        let alerts = OperationalIntelligenceService.deriveSurgeAlerts(
            incidents: incidents,
            districts: [smallerCritical, largerCritical],
            now: now
        )

        XCTAssertEqual(alerts.map(\.districtId), ["D-CRITICAL-B", "D-CRITICAL-A"])
        XCTAssertGreaterThan(alerts[0].percentageIncrease, alerts[1].percentageIncrease)
    }

    func testDeriveHazardScoreUsesLiveIncidentSignals() {
        let districts = [
            makeDistrict(id: "D-RISK", name: "Risk District"),
            makeDistrict(id: "D-NORMAL", name: "Normal District")
        ]
        let incidents = [
            makeIncident(id: "traffic", district: districts[0], severity: .high, type: "Traffic Collision", description: "Vehicle collision blocking road", reportedMinutesAgo: 10),
            makeIncident(id: "gas", district: districts[0], severity: .critical, type: "Gas Leak", description: "Gas utility outage with fire risk", reportedMinutesAgo: 20),
            makeIncident(id: "closed", district: districts[0], status: .closed, severity: .critical, type: "Structure Fire", reportedMinutesAgo: 30)
        ]
        let alerts = OperationalIntelligenceService.deriveSurgeAlerts(
            incidents: incidents,
            districts: districts,
            now: now
        )

        let hazard = OperationalIntelligenceService.deriveHazardScore(
            incidents: incidents,
            districts: districts,
            surgeAlerts: alerts,
            now: now
        )

        XCTAssertGreaterThan(hazard.overallScore, 20)
        XCTAssertEqual(hazard.lastUpdated, now)
        XCTAssertEqual(hazard.components.traffic.score, 18)
        XCTAssertEqual(hazard.components.infrastructureOutages.score, 22)
        XCTAssertEqual(hazard.components.incidentActivity.trend, .stable)
        XCTAssertEqual(hazard.districtScores.first?.districtId, "D-RISK")
        XCTAssertEqual(hazard.districtScores.first?.primaryRisk, "Call Surge")
        XCTAssertEqual(hazard.districtScores.last?.primaryRisk, "Normal")
    }

    func testDeriveHazardTrendDataIsStableAndEndsAtCurrentScore() {
        let hazard = HazardScore(
            id: "test-hazard",
            overallScore: 42,
            lastUpdated: now,
            components: .init(
                weather: .init(score: 10, weight: 0.15, trend: .stable, details: ""),
                traffic: .init(score: 20, weight: 0.20, trend: .stable, details: ""),
                incidentActivity: .init(score: 30, weight: 0.35, trend: .stable, details: ""),
                infrastructureOutages: .init(score: 0, weight: 0.15, trend: .stable, details: ""),
                specialEvents: .init(score: 0, weight: 0.15, trend: .stable, details: "")
            ),
            historicalComparison: .init(yesterdayScore: 35, lastWeekAverage: 28, lastMonthAverage: 25),
            districtScores: []
        )

        let trend = OperationalIntelligenceService.deriveHazardTrendData(for: hazard)

        XCTAssertEqual(trend.count, 8)
        XCTAssertEqual(trend.map(\.id), (0..<8).map { "sf-hazard-trend-\($0)" })
        XCTAssertEqual(trend.first?.score, 28)
        XCTAssertEqual(trend.dropLast().last?.score, 35)
        XCTAssertEqual(trend.last?.score, 42)
    }

    func testEmptyInputsProduceBaselineIntelligenceWithoutRandomData() {
        let hazard = OperationalIntelligenceService.deriveHazardScore(
            incidents: [],
            districts: [],
            surgeAlerts: [],
            now: now
        )

        XCTAssertTrue(OperationalIntelligenceService.deriveSurgeAlerts(incidents: [], districts: [], now: now).isEmpty)
        XCTAssertEqual(hazard.id, "sf-hazard-live")
        XCTAssertEqual(hazard.overallScore, 2)
        XCTAssertEqual(hazard.components.weather.score, 10)
        XCTAssertTrue(hazard.districtScores.isEmpty)
    }

    private func makeDistrict(id: String, name: String) -> District {
        District(
            id: id,
            name: name,
            shortName: name.replacingOccurrences(of: " District", with: ""),
            population: 1_000,
            areaSquareMiles: 50,
            center: .init(latitude: 37.7749, longitude: -122.4194),
            boundaries: [],
            activeIncidents: 0,
            averageResponseTime: 5
        )
    }

    private func makeIncident(
        id: String,
        district: District,
        status: IncidentStatus = .active,
        severity: IncidentSeverity = .medium,
        type: String = "Medical Emergency",
        description: String = "Live San Francisco incident",
        reportedMinutesAgo: TimeInterval
    ) -> Incident {
        let reportedAt = now.addingTimeInterval(-reportedMinutesAgo * 60)
        return Incident(
            id: id,
            type: type,
            description: description,
            agencyType: .emergency911,
            agencyId: "SF-911",
            agencyName: "San Francisco 911",
            districtId: district.id,
            districtName: district.name,
            status: status,
            severity: severity,
            location: .init(latitude: 37.7749, longitude: -122.4194),
            address: "1 Market St, San Francisco, CA",
            reportedAt: reportedAt,
            updatedAt: reportedAt.addingTimeInterval(60),
            respondingUnits: [],
            notes: nil
        )
    }
}
