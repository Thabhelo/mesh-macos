import Foundation

enum DataMode: String, CaseIterable, Identifiable {
    case live = "Live DataSF"
    case replay = "Replay Training"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .live: return "Live"
        case .replay: return "Replay Training"
        }
    }

    var detail: String {
        switch self {
        case .live:
            return "San Francisco DataSF rolling incident snapshot"
        case .replay:
            return "Replay drill: SF surge triage scenario, not live production data"
        }
    }
}

enum ReplayPlaybackState: String {
    case stopped
    case playing
    case paused
}

enum ReplaySpeed: Double, CaseIterable, Identifiable {
    case normal = 1
    case fast = 2
    case faster = 4

    var id: Double { rawValue }
    var label: String { "\(Int(rawValue))x" }
}

struct ReplayScenarioFrame: Identifiable, Equatable {
    let id: String
    let stepNumber: Int
    let timestamp: Date
    let title: String
    let whatChanged: String
    let whyItMatters: String
    let recommendedAction: String
    let evidence: [String]
    let incidents: [Incident]

    var incidentResult: IncidentPollingResult {
        IncidentPollingResult(
            incidents: incidents,
            updates: incidents.map {
                IncidentUpdate(type: .new, incident: $0, incidentId: $0.id, timestamp: timestamp)
            },
            refreshedAt: timestamp,
            sourceDataAsOf: timestamp,
            sourceDataLoadedAt: timestamp
        )
    }
}

enum ReplayScenarioService {
    static let title = "SF Bay Bridge Surge Drill"
    static let usefulnessClaim = "Detect a Southern District surge and stage fire/EMS units before raw call scanning would reveal the cluster."

    static func frames(anchorDate: Date = Date()) -> [ReplayScenarioFrame] {
        let start = anchorDate.addingTimeInterval(-20 * 60)
        let frame0Time = start
        let frame1Time = start.addingTimeInterval(5 * 60)
        let frame2Time = start.addingTimeInterval(10 * 60)
        let frame3Time = start.addingTimeInterval(15 * 60)
        let frame4Time = start.addingTimeInterval(20 * 60)

        let baseline = [
            incident(
                id: "SF-REPLAY-001",
                type: "Medical Emergency",
                description: "Medical aid requested at Powell Street Station concourse.",
                agencyType: .ems,
                agencyId: "SFFD-EMS-01",
                agencyName: "San Francisco EMS",
                districtId: "D-02",
                districtName: "Central District",
                status: .responding,
                severity: .medium,
                latitude: 37.7844,
                longitude: -122.4078,
                address: "Powell St Station, San Francisco, CA",
                reportedAt: frame0Time.addingTimeInterval(-4 * 60),
                updatedAt: frame0Time,
                respondingUnits: [
                    unit(id: "R-U1", unitId: "SFEMS-M12", unitName: "Medic 12", agencyType: .ems, status: "En Route", etaMinutes: 4)
                ]
            ),
            incident(
                id: "SF-REPLAY-002",
                type: "Vehicle Fire",
                description: "Vehicle fire reported near Golden Gate Park with SFFD responding.",
                agencyType: .fire,
                agencyId: "SFFD-01",
                agencyName: "San Francisco Fire Department",
                districtId: "D-01",
                districtName: "Northern District",
                status: .onScene,
                severity: .medium,
                latitude: 37.7694,
                longitude: -122.4862,
                address: "Fulton St & 30th Ave, San Francisco, CA",
                reportedAt: frame0Time.addingTimeInterval(-7 * 60),
                updatedAt: frame0Time,
                respondingUnits: [
                    unit(id: "R-U2", unitId: "SFFD-E31", unitName: "Engine 31", agencyType: .fire, status: "On Scene", etaMinutes: nil)
                ]
            )
        ]

        let bayBridgeCluster = [
            incident(
                id: "SF-REPLAY-003",
                type: "Traffic Collision",
                description: "Multi-vehicle collision blocking the Bay Bridge approach.",
                agencyType: .police,
                agencyId: "SFPD-01",
                agencyName: "San Francisco Police Department",
                districtId: "D-03",
                districtName: "Southern District",
                status: .active,
                severity: .high,
                latitude: 37.7898,
                longitude: -122.3915,
                address: "I-80 W at 5th St, San Francisco, CA",
                reportedAt: frame1Time.addingTimeInterval(-2 * 60),
                updatedAt: frame1Time,
                respondingUnits: [
                    unit(id: "R-U3", unitId: "SFPD-3A45", unitName: "Southern Patrol 45", agencyType: .police, status: "En Route", etaMinutes: 3),
                    unit(id: "R-U4", unitId: "SFEMS-M03", unitName: "Medic 3", agencyType: .ems, status: "Staging", etaMinutes: nil)
                ]
            ),
            incident(
                id: "SF-REPLAY-004",
                type: "Medical Emergency",
                description: "Pedestrian injury near the freeway ramp during traffic backup.",
                agencyType: .ems,
                agencyId: "SFFD-EMS-01",
                agencyName: "San Francisco EMS",
                districtId: "D-03",
                districtName: "Southern District",
                status: .responding,
                severity: .high,
                latitude: 37.7816,
                longitude: -122.4047,
                address: "5th St & Bryant St, San Francisco, CA",
                reportedAt: frame1Time.addingTimeInterval(-1 * 60),
                updatedAt: frame1Time,
                respondingUnits: [
                    unit(id: "R-U5", unitId: "SFEMS-M05", unitName: "Medic 5", agencyType: .ems, status: "En Route", etaMinutes: 5)
                ]
            )
        ]

        let escalation = [
            incident(
                id: "SF-REPLAY-005",
                type: "Structure Fire",
                description: "Smoke visible from mixed-use building near Moscone Center.",
                agencyType: .fire,
                agencyId: "SFFD-01",
                agencyName: "San Francisco Fire Department",
                districtId: "D-03",
                districtName: "Southern District",
                status: .responding,
                severity: .critical,
                latitude: 37.7840,
                longitude: -122.4010,
                address: "Howard St & 4th St, San Francisco, CA",
                reportedAt: frame2Time.addingTimeInterval(-2 * 60),
                updatedAt: frame2Time,
                respondingUnits: [
                    unit(id: "R-U6", unitId: "SFFD-E01", unitName: "Engine 1", agencyType: .fire, status: "En Route", etaMinutes: 2),
                    unit(id: "R-U7", unitId: "SFFD-T01", unitName: "Truck 1", agencyType: .fire, status: "En Route", etaMinutes: 4)
                ]
            ),
            incident(
                id: "SF-REPLAY-006",
                type: "Transit Delay",
                description: "Transit blockage and crowding near Montgomery Station.",
                agencyType: .transit,
                agencyId: "SFMTA-01",
                agencyName: "San Francisco Municipal Transportation Agency",
                districtId: "D-03",
                districtName: "Southern District",
                status: .active,
                severity: .medium,
                latitude: 37.7894,
                longitude: -122.4010,
                address: "Montgomery St Station, San Francisco, CA",
                reportedAt: frame2Time.addingTimeInterval(-1 * 60),
                updatedAt: frame2Time,
                respondingUnits: [
                    unit(id: "R-U8", unitId: "SFMTA-FIELD-2", unitName: "Field Unit 2", agencyType: .transit, status: "Assigned", etaMinutes: 6)
                ]
            )
        ]

        let peak = [
            incident(
                id: "SF-REPLAY-007",
                type: "Gas Leak",
                description: "Gas odor reported in a South of Market residential building.",
                agencyType: .fire,
                agencyId: "SFFD-01",
                agencyName: "San Francisco Fire Department",
                districtId: "D-03",
                districtName: "Southern District",
                status: .responding,
                severity: .critical,
                latitude: 37.7765,
                longitude: -122.3972,
                address: "3rd St & Townsend St, San Francisco, CA",
                reportedAt: frame3Time.addingTimeInterval(-90),
                updatedAt: frame3Time,
                respondingUnits: [
                    unit(id: "R-U9", unitId: "SFFD-E08", unitName: "Engine 8", agencyType: .fire, status: "En Route", etaMinutes: 3),
                    unit(id: "R-U10", unitId: "SFFD-HM1", unitName: "Hazmat 1", agencyType: .fire, status: "En Route", etaMinutes: 8)
                ]
            ),
            incident(
                id: "SF-REPLAY-008",
                type: "Assault",
                description: "Assault with injuries reported near Civic Center during traffic diversion.",
                agencyType: .police,
                agencyId: "SFPD-01",
                agencyName: "San Francisco Police Department",
                districtId: "D-03",
                districtName: "Southern District",
                status: .active,
                severity: .high,
                latitude: 37.7793,
                longitude: -122.4140,
                address: "Market St & 8th St, San Francisco, CA",
                reportedAt: frame3Time.addingTimeInterval(-60),
                updatedAt: frame3Time,
                respondingUnits: [
                    unit(id: "R-U11", unitId: "SFPD-3B18", unitName: "Southern Patrol 18", agencyType: .police, status: "En Route", etaMinutes: 4)
                ]
            )
        ]

        var resolvingIncident = bayBridgeCluster[0]
        resolvingIncident.status = .resolved
        resolvingIncident.updatedAt = frame4Time

        return [
            frame(
                id: "baseline",
                stepNumber: 1,
                timestamp: frame0Time,
                title: "Baseline SF Operations",
                whatChanged: "Normal live-call volume across Central and Northern districts.",
                whyItMatters: "Operators have no surge signal yet; the dashboard should stay low-noise.",
                recommendedAction: "Keep normal monitoring posture and verify live/replay mode before making decisions.",
                evidence: ["2 active incidents", "No district surge", "Hazard score remains near baseline"],
                incidents: baseline
            ),
            frame(
                id: "cluster-start",
                stepNumber: 2,
                timestamp: frame1Time,
                title: "Bay Bridge Approach Cluster",
                whatChanged: "Two high-priority calls appear in Southern District near I-80 and 5th Street.",
                whyItMatters: "The cluster is still small, but geography suggests shared congestion and response-route risk.",
                recommendedAction: "Watch Southern District, stage one EMS unit near 5th/Market, and confirm SFPD/SFFD routing.",
                evidence: ["2 Southern District high-priority incidents", "Bay Bridge approach address cluster", "EMS already staging"],
                incidents: baseline + bayBridgeCluster
            ),
            frame(
                id: "surge-detected",
                stepNumber: 3,
                timestamp: frame2Time,
                title: "Southern District Surge Detected",
                whatChanged: "A critical structure fire and transit blockage push Southern District above its expected baseline.",
                whyItMatters: "The same corridor now combines fire, EMS, police, and transit demand.",
                recommendedAction: "Escalate Southern District to surge watch and pre-position fire/EMS units outside the congestion area.",
                evidence: ["Critical fire near Moscone", "Transit delay near Montgomery", "Cross-agency demand in one district"],
                incidents: baseline + bayBridgeCluster + escalation
            ),
            frame(
                id: "hazard-peak",
                stepNumber: 4,
                timestamp: frame3Time,
                title: "Hazard Escalation",
                whatChanged: "A gas leak and assault add more high-priority work to the same operational area.",
                whyItMatters: "Hazard risk rises because infrastructure, traffic, and incident activity overlap.",
                recommendedAction: "Prioritize Southern District dispatch coordination and route new units around I-80 congestion.",
                evidence: ["2 critical incidents", "6 active Southern District incidents", "Surge and hazard scores rise together"],
                incidents: baseline + bayBridgeCluster + escalation + peak
            ),
            frame(
                id: "resolution",
                stepNumber: 5,
                timestamp: frame4Time,
                title: "Resolution Tracking",
                whatChanged: "The initial collision is resolved while fire, gas, and EMS incidents remain active.",
                whyItMatters: "Operators can see whether staging reduced the corridor load and which risks still need attention.",
                recommendedAction: "Release traffic resources gradually, keep hazmat/fire units committed, and monitor for renewed surge.",
                evidence: ["Collision resolved", "Critical fire and gas leak still active", "Southern District remains the priority district"],
                incidents: baseline + [resolvingIncident, bayBridgeCluster[1]] + escalation + peak
            )
        ]
    }

    private static func frame(
        id: String,
        stepNumber: Int,
        timestamp: Date,
        title: String,
        whatChanged: String,
        whyItMatters: String,
        recommendedAction: String,
        evidence: [String],
        incidents: [Incident]
    ) -> ReplayScenarioFrame {
        ReplayScenarioFrame(
            id: id,
            stepNumber: stepNumber,
            timestamp: timestamp,
            title: title,
            whatChanged: whatChanged,
            whyItMatters: whyItMatters,
            recommendedAction: recommendedAction,
            evidence: evidence,
            incidents: incidents.sorted { lhs, rhs in
                if lhs.status.isOperationallyActive != rhs.status.isOperationallyActive {
                    return lhs.status.isOperationallyActive
                }
                return lhs.updatedAt > rhs.updatedAt
            }
        )
    }

    private static func incident(
        id: String,
        type: String,
        description: String,
        agencyType: AgencyType,
        agencyId: String,
        agencyName: String,
        districtId: String,
        districtName: String,
        status: IncidentStatus,
        severity: IncidentSeverity,
        latitude: Double,
        longitude: Double,
        address: String,
        reportedAt: Date,
        updatedAt: Date,
        respondingUnits: [Incident.RespondingUnit]
    ) -> Incident {
        Incident(
            id: id,
            type: type,
            description: description,
            agencyType: agencyType,
            agencyId: agencyId,
            agencyName: agencyName,
            districtId: districtId,
            districtName: districtName,
            status: status,
            severity: severity,
            location: .init(latitude: latitude, longitude: longitude),
            address: address,
            reportedAt: reportedAt,
            updatedAt: updatedAt,
            respondingUnits: respondingUnits,
            notes: [
                .init(
                    id: "\(id)-note",
                    content: "Replay training event sourced from an SF operational drill sequence.",
                    author: "Mesh Replay",
                    timestamp: updatedAt
                )
            ]
        )
    }

    private static func unit(
        id: String,
        unitId: String,
        unitName: String,
        agencyType: AgencyType,
        status: String,
        etaMinutes: Int?
    ) -> Incident.RespondingUnit {
        .init(id: id, unitId: unitId, unitName: unitName, agencyType: agencyType, status: status, etaMinutes: etaMinutes)
    }
}
