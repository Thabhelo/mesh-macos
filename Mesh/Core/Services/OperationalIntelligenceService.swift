import Foundation

struct HazardTrendDataPoint: Identifiable {
    let id: String
    let date: Date
    let score: Int
}

enum OperationalIntelligenceService {
    static func deriveSurgeAlerts(
        incidents: [Incident],
        districts: [District],
        now: Date = Date()
    ) -> [SurgeAlert] {
        districts.compactMap { district in
            let districtIncidents = incidents.filter { $0.districtId == district.id || $0.districtName == district.name }
            let activeIncidents = districtIncidents.filter { $0.status.isOperationallyActive }
            let recentIncidents = districtIncidents.filter {
                $0.reportedAt >= now.addingTimeInterval(-2 * 60 * 60) || $0.updatedAt >= now.addingTimeInterval(-2 * 60 * 60)
            }
            let currentVolume = max(activeIncidents.count, recentIncidents.count)
            let expectedVolume = expectedCallVolume(for: district, at: now, windowHours: 2)

            guard currentVolume > expectedVolume else {
                return nil
            }

            let percentageIncrease = Double(currentVolume - expectedVolume) / Double(max(expectedVolume, 1)) * 100
            guard percentageIncrease >= 20 || currentVolume >= expectedVolume + 2 else {
                return nil
            }

            let trend = surgeTrend(for: districtIncidents, now: now)
            let severity = surgeSeverity(
                percentageIncrease: percentageIncrease,
                criticalCount: activeIncidents.filter { $0.severity == .critical }.count
            )

            return SurgeAlert(
                id: "sf-surge-\(district.id)",
                districtId: district.id,
                districtName: district.name,
                severity: severity,
                currentCallVolume: currentVolume,
                expectedCallVolume: expectedVolume,
                percentageIncrease: percentageIncrease,
                trend: trend,
                triggeredAt: activeIncidents.map(\.updatedAt).max() ?? now,
                predictedPeakTime: trend == .rising ? now.addingTimeInterval(60 * 60) : nil,
                confidenceScore: confidenceScore(currentVolume: currentVolume, percentageIncrease: percentageIncrease),
                contributingFactors: surgeFactors(
                    incidents: activeIncidents,
                    currentVolume: currentVolume,
                    expectedVolume: expectedVolume
                )
            )
        }
        .sorted { lhs, rhs in
            if lhs.severity != rhs.severity {
                return lhs.severity > rhs.severity
            }
            return lhs.percentageIncrease > rhs.percentageIncrease
        }
    }

    static func deriveSurgeTrendData(
        incidents: [Incident],
        districts: [District],
        districtId: String?,
        hours: Int,
        now: Date = Date()
    ) -> [SurgeTrendDataPoint] {
        let interval = bucketInterval(forHours: hours)
        let bucketCount = max(1, Int(ceil(Double(hours) * 60 * 60 / interval)))
        let district = districts.first { $0.id == districtId }
        let filteredIncidents = incidents.filter { incident in
            guard let districtId, districtId != "all" else { return true }
            return incident.districtId == districtId || district?.name == incident.districtName
        }

        return (0..<bucketCount).reversed().map { offset in
            let bucketStart = now.addingTimeInterval(-Double(offset + 1) * interval)
            let bucketEnd = bucketStart.addingTimeInterval(interval)
            let callVolume = filteredIncidents.filter {
                $0.reportedAt >= bucketStart && $0.reportedAt < bucketEnd
            }.count
            let expectedVolume = expectedCallVolume(
                for: district,
                at: bucketStart,
                windowHours: interval / (60 * 60)
            )

            return SurgeTrendDataPoint(
                id: "sf-trend-\(districtId ?? "all")-\(Int(bucketStart.timeIntervalSince1970))",
                timestamp: bucketStart,
                callVolume: callVolume,
                expectedVolume: expectedVolume
            )
        }
    }

    static func deriveHazardScore(
        incidents: [Incident],
        districts: [District],
        surgeAlerts: [SurgeAlert],
        now: Date = Date()
    ) -> HazardScore {
        let activeIncidents = incidents.filter { $0.status.isOperationallyActive }
        let criticalCount = activeIncidents.filter { $0.severity == .critical }.count
        let highCount = activeIncidents.filter { $0.severity == .high }.count
        let trafficCount = activeIncidents.filter { isTrafficRelated($0) }.count
        let infrastructureCount = activeIncidents.filter { isInfrastructureRelated($0) }.count
        let surgeScore = min(100, surgeAlerts.reduce(0) { $0 + ($1.severity.rawValue * 18) })

        let incidentActivityScore = min(100, activeIncidents.count * 6 + criticalCount * 14 + highCount * 8)
        let trafficScore = min(100, trafficCount * 18)
        let infrastructureScore = min(100, infrastructureCount * 22)
        let specialEventsScore = min(100, surgeAlerts.filter { $0.contributingFactors.contains(where: { $0.localizedCaseInsensitiveContains("event") }) }.count * 25)
        let weatherScore = 10

        let components = HazardScore.HazardComponents(
            weather: .init(
                score: weatherScore,
                weight: 0.15,
                trend: .stable,
                details: "No live Bay Area weather alert adapter is integrated yet; using neutral SF baseline."
            ),
            traffic: .init(
                score: trafficScore,
                weight: 0.20,
                trend: trafficScore >= 50 ? .worsening : .stable,
                details: "\(trafficCount) active traffic or vehicle-related incidents in the SF incident snapshot."
            ),
            incidentActivity: .init(
                score: max(incidentActivityScore, surgeScore),
                weight: 0.35,
                trend: activeIncidents.count > max(1, districts.count) ? .worsening : .stable,
                details: "\(activeIncidents.count) active incidents, \(criticalCount) critical, \(highCount) high priority."
            ),
            infrastructureOutages: .init(
                score: infrastructureScore,
                weight: 0.15,
                trend: infrastructureScore >= 50 ? .worsening : .stable,
                details: "\(infrastructureCount) active incidents mention utility, gas, power, fire, or outage context."
            ),
            specialEvents: .init(
                score: specialEventsScore,
                weight: 0.15,
                trend: .stable,
                details: "No live special-events adapter is integrated yet; event risk is inferred only from surge factors."
            )
        )

        let overallScore = min(100, Int(round(components.allComponents.reduce(0) { $0 + $1.score.weightedScore })))
        let historicalComparison = deterministicComparison(for: overallScore, incidentActivityScore: incidentActivityScore)

        return HazardScore(
            id: "sf-hazard-live",
            overallScore: overallScore,
            lastUpdated: now,
            components: components,
            historicalComparison: historicalComparison,
            districtScores: deriveDistrictHazardScores(
                incidents: activeIncidents,
                districts: districts,
                surgeAlerts: surgeAlerts
            )
        )
    }

    static func deriveHazardTrendData(
        for hazard: HazardScore,
        calendar: Calendar = .current
    ) -> [HazardTrendDataPoint] {
        let today = calendar.startOfDay(for: hazard.lastUpdated)
        let anchors = [
            hazard.historicalComparison.lastWeekAverage,
            interpolatedScore(from: hazard.historicalComparison.lastWeekAverage, to: hazard.historicalComparison.yesterdayScore, step: 1, totalSteps: 6),
            interpolatedScore(from: hazard.historicalComparison.lastWeekAverage, to: hazard.historicalComparison.yesterdayScore, step: 2, totalSteps: 6),
            interpolatedScore(from: hazard.historicalComparison.lastWeekAverage, to: hazard.historicalComparison.yesterdayScore, step: 3, totalSteps: 6),
            interpolatedScore(from: hazard.historicalComparison.lastWeekAverage, to: hazard.historicalComparison.yesterdayScore, step: 4, totalSteps: 6),
            interpolatedScore(from: hazard.historicalComparison.lastWeekAverage, to: hazard.historicalComparison.yesterdayScore, step: 5, totalSteps: 6),
            hazard.historicalComparison.yesterdayScore,
            hazard.overallScore
        ]

        return anchors.enumerated().map { index, score in
            let daysFromToday = index - (anchors.count - 1)
            let date = calendar.date(byAdding: .day, value: daysFromToday, to: today) ?? today
            return HazardTrendDataPoint(id: "sf-hazard-trend-\(index)", date: date, score: score)
        }
    }

    private static func bucketInterval(forHours hours: Int) -> TimeInterval {
        switch hours {
        case 0...24:
            return 15 * 60
        default:
            return 6 * 60 * 60
        }
    }

    private static func expectedCallVolume(for district: District?, at date: Date, windowHours: Double) -> Int {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let weekday = calendar.component(.weekday, from: date)

        let timeMultiplier: Double
        switch hour {
        case 6..<9:
            timeMultiplier = 1.35
        case 17..<20:
            timeMultiplier = 1.45
        case 22...23, 0..<5:
            timeMultiplier = 0.70
        default:
            timeMultiplier = 1.0
        }

        let weekendMultiplier = [1, 7].contains(weekday) ? 1.10 : 1.0
        let populationFactor = district.map { max(0.8, Double($0.population) / 75_000) } ?? 5.5
        let areaFactor = district.map { max(0.8, min(1.4, 6.0 / max($0.areaSquareMiles, 1.0))) } ?? 1.0
        let expected = populationFactor * areaFactor * timeMultiplier * weekendMultiplier * max(windowHours, 0.25)

        return max(1, Int(round(expected)))
    }

    private static func surgeTrend(for incidents: [Incident], now: Date) -> SurgeAlert.SurgeTrend {
        let recent = incidents.filter { $0.reportedAt >= now.addingTimeInterval(-60 * 60) }.count
        let previous = incidents.filter {
            $0.reportedAt >= now.addingTimeInterval(-2 * 60 * 60) && $0.reportedAt < now.addingTimeInterval(-60 * 60)
        }.count

        if recent > previous {
            return .rising
        }
        if recent < previous {
            return .declining
        }
        return .stable
    }

    private static func surgeSeverity(percentageIncrease: Double, criticalCount: Int) -> SurgeSeverity {
        if percentageIncrease >= 100 || criticalCount >= 2 {
            return .critical
        }
        if percentageIncrease >= 60 || criticalCount >= 1 {
            return .high
        }
        if percentageIncrease >= 20 {
            return .elevated
        }
        return .normal
    }

    private static func confidenceScore(currentVolume: Int, percentageIncrease: Double) -> Double {
        min(0.95, 0.55 + min(abs(percentageIncrease) / 200, 0.25) + min(Double(currentVolume) / 40, 0.15))
    }

    private static func surgeFactors(
        incidents: [Incident],
        currentVolume: Int,
        expectedVolume: Int
    ) -> [String] {
        var factors = [
            "\(currentVolume) active/recent calls vs \(expectedVolume) expected baseline"
        ]

        let criticalCount = incidents.filter { $0.severity == .critical }.count
        let highCount = incidents.filter { $0.severity == .high }.count
        if criticalCount > 0 {
            factors.append("\(criticalCount) critical-priority incidents")
        }
        if highCount > 0 {
            factors.append("\(highCount) high-priority incidents")
        }
        if let topType = topIncidentType(in: incidents) {
            factors.append("Most common category: \(topType)")
        }

        return factors
    }

    private static func topIncidentType(in incidents: [Incident]) -> String? {
        Dictionary(grouping: incidents, by: \.type)
            .map { (type: $0.key, count: $0.value.count) }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count {
                    return lhs.count > rhs.count
                }
                return lhs.type < rhs.type
            }
            .first?
            .type
    }

    private static func deterministicComparison(
        for overallScore: Int,
        incidentActivityScore: Int
    ) -> HazardScore.HistoricalComparison {
        let activityDelta = max(3, min(12, incidentActivityScore / 10))
        let yesterday = max(0, overallScore - activityDelta)
        let lastWeek = max(0, yesterday - 4)
        let lastMonth = max(0, lastWeek - 3)
        return .init(yesterdayScore: yesterday, lastWeekAverage: lastWeek, lastMonthAverage: lastMonth)
    }

    private static func deriveDistrictHazardScores(
        incidents: [Incident],
        districts: [District],
        surgeAlerts: [SurgeAlert]
    ) -> [HazardScore.DistrictHazardScore] {
        districts.map { district in
            let districtIncidents = incidents.filter { $0.districtId == district.id || $0.districtName == district.name }
            let criticalCount = districtIncidents.filter { $0.severity == .critical }.count
            let highCount = districtIncidents.filter { $0.severity == .high }.count
            let trafficCount = districtIncidents.filter { isTrafficRelated($0) }.count
            let surge = surgeAlerts.first { $0.districtId == district.id }
            let surgeContribution = (surge?.severity.rawValue ?? 0) * 15
            let score = min(100, districtIncidents.count * 8 + criticalCount * 20 + highCount * 10 + trafficCount * 8 + surgeContribution)

            return HazardScore.DistrictHazardScore(
                id: "sf-district-hazard-\(district.id)",
                districtId: district.id,
                districtName: district.shortName,
                score: score,
                primaryRisk: primaryRisk(
                    criticalCount: criticalCount,
                    trafficCount: trafficCount,
                    surge: surge,
                    incidentCount: districtIncidents.count
                )
            )
        }
        .sorted { lhs, rhs in
            if lhs.score != rhs.score {
                return lhs.score > rhs.score
            }
            return lhs.districtName < rhs.districtName
        }
    }

    private static func primaryRisk(
        criticalCount: Int,
        trafficCount: Int,
        surge: SurgeAlert?,
        incidentCount: Int
    ) -> String {
        if let surge, surge.severity >= .elevated {
            return "Call Surge"
        }
        if criticalCount > 0 {
            return "Critical Incidents"
        }
        if trafficCount > 0 {
            return "Traffic"
        }
        return incidentCount > 0 ? "Incident Activity" : "Normal"
    }

    private static func isTrafficRelated(_ incident: Incident) -> Bool {
        let text = "\(incident.type) \(incident.description)".lowercased()
        return ["traffic", "collision", "vehicle", "hit and run", "road", "transit"].contains { text.contains($0) }
    }

    private static func isInfrastructureRelated(_ incident: Incident) -> Bool {
        let text = "\(incident.type) \(incident.description) \(incident.address)".lowercased()
        return ["gas", "power", "outage", "utility", "fire", "wire", "flood"].contains { text.contains($0) }
    }

    private static func interpolatedScore(from start: Int, to end: Int, step: Int, totalSteps: Int) -> Int {
        let progress = Double(step) / Double(max(totalSteps, 1))
        return max(0, min(100, Int(round(Double(start) + (Double(end - start) * progress)))))
    }
}
