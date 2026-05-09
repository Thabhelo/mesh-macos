import Foundation

// MARK: - Wire types (JSON-compatible with the macOS app's Codable models)

public enum MeshSurgeSeverity: Int, Codable, Comparable, Sendable {
    case normal = 0
    case elevated = 1
    case high = 2
    case critical = 3

    public static func < (lhs: MeshSurgeSeverity, rhs: MeshSurgeSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum MeshSurgeTrend: String, Codable, Sendable {
    case rising = "Rising"
    case stable = "Stable"
    case declining = "Declining"
}

public struct SurgeAlertWire: Codable, Equatable, Sendable {
    public let id: String
    public let districtId: String
    public let districtName: String
    public let severity: MeshSurgeSeverity
    public let currentCallVolume: Int
    public let expectedCallVolume: Int
    public let percentageIncrease: Double
    public let trend: MeshSurgeTrend
    public let triggeredAt: Date
    public let predictedPeakTime: Date?
    public let confidenceScore: Double
    public let contributingFactors: [String]

    public init(
        id: String,
        districtId: String,
        districtName: String,
        severity: MeshSurgeSeverity,
        currentCallVolume: Int,
        expectedCallVolume: Int,
        percentageIncrease: Double,
        trend: MeshSurgeTrend,
        triggeredAt: Date,
        predictedPeakTime: Date?,
        confidenceScore: Double,
        contributingFactors: [String]
    ) {
        self.id = id
        self.districtId = districtId
        self.districtName = districtName
        self.severity = severity
        self.currentCallVolume = currentCallVolume
        self.expectedCallVolume = expectedCallVolume
        self.percentageIncrease = percentageIncrease
        self.trend = trend
        self.triggeredAt = triggeredAt
        self.predictedPeakTime = predictedPeakTime
        self.confidenceScore = confidenceScore
        self.contributingFactors = contributingFactors
    }
}

public struct SurgeTrendPointWire: Codable, Equatable, Sendable {
    public let id: String
    public let timestamp: Date
    public let callVolume: Int
    public let expectedVolume: Int

    public init(id: String, timestamp: Date, callVolume: Int, expectedVolume: Int) {
        self.id = id
        self.timestamp = timestamp
        self.callVolume = callVolume
        self.expectedVolume = expectedVolume
    }
}

public struct HazardScoreWire: Codable, Equatable, Sendable {
    public let id: String
    public let overallScore: Int
    public let lastUpdated: Date
    public let components: HazardComponentsWire
    public let historicalComparison: HistoricalComparisonWire
    public let districtScores: [DistrictHazardScoreWire]

    public struct HazardComponentsWire: Codable, Equatable, Sendable {
        public let weather: ComponentScoreWire
        public let traffic: ComponentScoreWire
        public let incidentActivity: ComponentScoreWire
        public let infrastructureOutages: ComponentScoreWire
        public let specialEvents: ComponentScoreWire
    }

    public struct ComponentScoreWire: Codable, Equatable, Sendable {
        public let score: Int
        public let weight: Double
        public let trend: ComponentTrendWire
        public let details: String

        public enum ComponentTrendWire: String, Codable, Sendable {
            case improving = "Improving"
            case stable = "Stable"
            case worsening = "Worsening"
        }
    }

    public struct HistoricalComparisonWire: Codable, Equatable, Sendable {
        public let yesterdayScore: Int
        public let lastWeekAverage: Int
        public let lastMonthAverage: Int
    }

    public struct DistrictHazardScoreWire: Codable, Equatable, Sendable {
        public let id: String
        public let districtId: String
        public let districtName: String
        public let score: Int
        public let primaryRisk: String
    }

    public init(
        id: String,
        overallScore: Int,
        lastUpdated: Date,
        components: HazardComponentsWire,
        historicalComparison: HistoricalComparisonWire,
        districtScores: [DistrictHazardScoreWire]
    ) {
        self.id = id
        self.overallScore = overallScore
        self.lastUpdated = lastUpdated
        self.components = components
        self.historicalComparison = historicalComparison
        self.districtScores = districtScores
    }
}

// MARK: - Incident helpers

extension IncidentPayload {
    var meshOperationallyActive: Bool {
        status == "Active" || status == "Responding" || status == "On Scene"
    }

    var meshSeverityCritical: Bool { severity == 4 }
    var meshSeverityHigh: Bool { severity == 3 }
}

// MARK: - Derived signals (mirrors macOS OperationalIntelligenceService numerics)

public enum MeshDerivedSignals {
    public struct DistrictBaseline: Equatable, Sendable {
        public let id: String
        public let name: String
        public let shortName: String
        public let population: Int
        public let areaSquareMiles: Double

        public init(id: String, name: String, shortName: String, population: Int, areaSquareMiles: Double) {
            self.id = id
            self.name = name
            self.shortName = shortName
            self.population = population
            self.areaSquareMiles = areaSquareMiles
        }
    }

    public static func deriveDistrictBaselines(from incidents: [IncidentPayload]) -> [DistrictBaseline] {
        Dictionary(grouping: incidents, by: \.districtId)
            .values
            .compactMap { districtIncidents -> DistrictBaseline? in
                guard let first = districtIncidents.first else { return nil }
                let latitudes = districtIncidents.map(\.location.latitude)
                let longitudes = districtIncidents.map(\.location.longitude)
                guard
                    let minLatitude = latitudes.min(),
                    let maxLatitude = latitudes.max(),
                    let minLongitude = longitudes.min(),
                    let maxLongitude = longitudes.max()
                else {
                    return nil
                }

                let centerLatitude = latitudes.reduce(0, +) / Double(latitudes.count)
                let padding = 0.005
                let latitudeMiles = max(0.1, (maxLatitude - minLatitude + 2 * padding) * 69)
                let longitudeMiles = max(
                    0.1,
                    (maxLongitude - minLongitude + 2 * padding) * cos(centerLatitude * .pi / 180) * 69
                )

                return DistrictBaseline(
                    id: first.districtId,
                    name: first.districtName,
                    shortName: first.districtName.replacingOccurrences(of: " District", with: ""),
                    population: 0,
                    areaSquareMiles: latitudeMiles * longitudeMiles
                )
            }
            .sorted { $0.name < $1.name }
    }

    public static func deriveSurgeAlerts(
        incidents: [IncidentPayload],
        now: Date = Date()
    ) -> [SurgeAlertWire] {
        let districts = deriveDistrictBaselines(from: incidents)
        return deriveSurgeAlerts(incidents: incidents, districts: districts, now: now)
    }

    public static func deriveSurgeAlerts(
        incidents: [IncidentPayload],
        districts: [DistrictBaseline],
        now: Date = Date()
    ) -> [SurgeAlertWire] {
        districts.compactMap { district -> SurgeAlertWire? in
            let districtIncidents = incidents.filter { $0.districtId == district.id || $0.districtName == district.name }
            let activeIncidents = districtIncidents.filter(\.meshOperationallyActive)
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
                criticalCount: activeIncidents.filter(\.meshSeverityCritical).count
            )

            return SurgeAlertWire(
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

    public static func deriveSurgeTrendSeries(
        incidents: [IncidentPayload],
        districtId: String?,
        hours: Int,
        now: Date = Date()
    ) -> [SurgeTrendPointWire] {
        let districts = deriveDistrictBaselines(from: incidents)
        let district = districts.first { $0.id == districtId }
        let interval = bucketInterval(forHours: hours)
        let bucketCount = max(1, Int(ceil(Double(hours) * 60 * 60 / interval)))
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

            return SurgeTrendPointWire(
                id: "sf-trend-\(districtId ?? "all")-\(Int(bucketStart.timeIntervalSince1970))",
                timestamp: bucketStart,
                callVolume: callVolume,
                expectedVolume: expectedVolume
            )
        }
    }

    public static func deriveHazardScore(
        incidents: [IncidentPayload],
        surgeAlerts: [SurgeAlertWire],
        now: Date = Date()
    ) -> HazardScoreWire {
        let districts = deriveDistrictBaselines(from: incidents)
        let activeIncidents = incidents.filter(\.meshOperationallyActive)
        let criticalCount = activeIncidents.filter(\.meshSeverityCritical).count
        let highCount = activeIncidents.filter(\.meshSeverityHigh).count
        let trafficCount = activeIncidents.filter(isTrafficRelated).count
        let infrastructureCount = activeIncidents.filter(isInfrastructureRelated).count
        let surgeScore = min(100, surgeAlerts.reduce(0) { $0 + ($1.severity.rawValue * 18) })

        let incidentActivityScore = min(100, activeIncidents.count * 6 + criticalCount * 14 + highCount * 8)
        let trafficScore = min(100, trafficCount * 18)
        let infrastructureScore = min(100, infrastructureCount * 22)
        let specialEventsScore = min(
            100,
            surgeAlerts.filter { $0.contributingFactors.contains(where: { $0.localizedCaseInsensitiveContains("event") }) }.count * 25
        )
        let weatherScore = 10

        let components = HazardScoreWire.HazardComponentsWire(
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

        let overallScore = min(
            100,
            Int(
                round(
                    [
                        (components.weather.score, components.weather.weight),
                        (components.traffic.score, components.traffic.weight),
                        (components.incidentActivity.score, components.incidentActivity.weight),
                        (components.infrastructureOutages.score, components.infrastructureOutages.weight),
                        (components.specialEvents.score, components.specialEvents.weight)
                    ].reduce(0) { $0 + Double($1.0) * $1.1 }
                )
            )
        )
        let historicalComparison = deterministicComparison(for: overallScore, incidentActivityScore: incidentActivityScore)

        return HazardScoreWire(
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

    private static func bucketInterval(forHours hours: Int) -> TimeInterval {
        switch hours {
        case 0...24:
            return 15 * 60
        default:
            return 6 * 60 * 60
        }
    }

    private static func expectedCallVolume(
        for district: DistrictBaseline?,
        at date: Date,
        windowHours: Double
    ) -> Int {
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

    private static func surgeTrend(for incidents: [IncidentPayload], now: Date) -> MeshSurgeTrend {
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

    private static func surgeSeverity(percentageIncrease: Double, criticalCount: Int) -> MeshSurgeSeverity {
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
        incidents: [IncidentPayload],
        currentVolume: Int,
        expectedVolume: Int
    ) -> [String] {
        var factors = [
            "\(currentVolume) active/recent calls vs \(expectedVolume) expected baseline"
        ]

        let criticalCount = incidents.filter(\.meshSeverityCritical).count
        let highCount = incidents.filter(\.meshSeverityHigh).count
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

    private static func topIncidentType(in incidents: [IncidentPayload]) -> String? {
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
    ) -> HazardScoreWire.HistoricalComparisonWire {
        let activityDelta = max(3, min(12, incidentActivityScore / 10))
        let yesterday = max(0, overallScore - activityDelta)
        let lastWeek = max(0, yesterday - 4)
        let lastMonth = max(0, lastWeek - 3)
        return .init(yesterdayScore: yesterday, lastWeekAverage: lastWeek, lastMonthAverage: lastMonth)
    }

    private static func deriveDistrictHazardScores(
        incidents: [IncidentPayload],
        districts: [DistrictBaseline],
        surgeAlerts: [SurgeAlertWire]
    ) -> [HazardScoreWire.DistrictHazardScoreWire] {
        districts.map { district in
            let districtIncidents = incidents.filter { $0.districtId == district.id || $0.districtName == district.name }
            let criticalCount = districtIncidents.filter(\.meshSeverityCritical).count
            let highCount = districtIncidents.filter(\.meshSeverityHigh).count
            let trafficCount = districtIncidents.filter(isTrafficRelated).count
            let surge = surgeAlerts.first { $0.districtId == district.id }
            let surgeContribution = (surge?.severity.rawValue ?? 0) * 15
            let score = min(
                100,
                districtIncidents.count * 8 + criticalCount * 20 + highCount * 10 + trafficCount * 8 + surgeContribution
            )

            return HazardScoreWire.DistrictHazardScoreWire(
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
        surge: SurgeAlertWire?,
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

    private static func isTrafficRelated(_ incident: IncidentPayload) -> Bool {
        let text = "\(incident.type) \(incident.description)".lowercased()
        return ["traffic", "collision", "vehicle", "hit and run", "road", "transit"].contains { text.contains($0) }
    }

    private static func isInfrastructureRelated(_ incident: IncidentPayload) -> Bool {
        let text = "\(incident.type) \(incident.description) \(incident.address)".lowercased()
        return ["gas", "power", "outage", "utility", "fire", "wire", "flood"].contains { text.contains($0) }
    }
}
