import Foundation
import SwiftUI
import CoreLocation

enum AgencyType: String, Codable, CaseIterable, Identifiable {
    case police = "Police"
    case fire = "Fire"
    case ems = "EMS"
    case emergency911 = "911"
    case transit = "Transit"
    case hospital = "Hospital"
    
    var id: String { rawValue }
    
    var color: Color {
        switch self {
        case .police: return .blue
        case .fire: return .red
        case .ems: return .orange
        case .emergency911: return .purple
        case .transit: return .green
        case .hospital: return .pink
        }
    }
    
    var icon: String {
        switch self {
        case .police: return "shield.fill"
        case .fire: return "flame.fill"
        case .ems: return "cross.fill"
        case .emergency911: return "phone.fill"
        case .transit: return "bus.fill"
        case .hospital: return "building.2.fill"
        }
    }
}

enum IncidentStatus: String, Codable, CaseIterable {
    case active = "Active"
    case responding = "Responding"
    case onScene = "On Scene"
    case resolved = "Resolved"
    case closed = "Closed"
    
    var color: Color {
        switch self {
        case .active: return .red
        case .responding: return .orange
        case .onScene: return .yellow
        case .resolved: return .green
        case .closed: return .gray
        }
    }
}

enum IncidentSeverity: Int, Codable, Comparable {
    case low = 1
    case medium = 2
    case high = 3
    case critical = 4
    
    static func < (lhs: IncidentSeverity, rhs: IncidentSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    var label: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}

struct Incident: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let type: String
    let description: String
    let agencyType: AgencyType
    let agencyId: String
    let agencyName: String
    let districtId: String
    let districtName: String
    var status: IncidentStatus
    let severity: IncidentSeverity
    let location: Location
    let address: String
    let reportedAt: Date
    var updatedAt: Date
    let respondingUnits: [RespondingUnit]
    let notes: [IncidentNote]?
    
    struct Location: Codable, Equatable, Hashable {
        let latitude: Double
        let longitude: Double
        
        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }
    
    struct RespondingUnit: Codable, Equatable, Identifiable, Hashable {
        let id: String
        let unitId: String
        let unitName: String
        let agencyType: AgencyType
        let status: String
        let etaMinutes: Int?
    }
    
    struct IncidentNote: Codable, Equatable, Identifiable, Hashable {
        let id: String
        let content: String
        let author: String
        let timestamp: Date
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: reportedAt, relativeTo: Date())
    }
    
    var coordinate: CLLocationCoordinate2D {
        location.coordinate
    }
}

// MARK: - Incident Update (for WebSocket)

enum IncidentUpdateType: String, Codable {
    case new
    case updated
    case closed
}

struct IncidentUpdate: Codable {
    let type: IncidentUpdateType
    let incident: Incident?
    let incidentId: String?
    let timestamp: Date
}

// MARK: - Sample Data

extension Incident {
    static let sample = Incident(
        id: "INC-001",
        type: "Structure Fire",
        description: "Two-story residential structure fire with possible entrapment",
        agencyType: .fire,
        agencyId: "BFD-01",
        agencyName: "Birmingham Fire Department",
        districtId: "D-05",
        districtName: "District 5 - Southside",
        status: .responding,
        severity: .critical,
        location: Location(latitude: 33.5186, longitude: -86.8104),
        address: "1234 5th Ave S, Birmingham, AL 35233",
        reportedAt: Date().addingTimeInterval(-300),
        updatedAt: Date(),
        respondingUnits: [
            RespondingUnit(id: "U1", unitId: "E-12", unitName: "Engine 12", agencyType: .fire, status: "En Route", etaMinutes: 3),
            RespondingUnit(id: "U2", unitId: "L-8", unitName: "Ladder 8", agencyType: .fire, status: "En Route", etaMinutes: 5),
            RespondingUnit(id: "U3", unitId: "M-7", unitName: "Medic 7", agencyType: .ems, status: "Staging", etaMinutes: nil)
        ],
        notes: nil
    )
    
    static let samples: [Incident] = [
        sample,
        Incident(
            id: "INC-002",
            type: "Traffic Accident",
            description: "Multi-vehicle accident with injuries on I-65",
            agencyType: .police,
            agencyId: "BPD-01",
            agencyName: "Birmingham Police Department",
            districtId: "D-03",
            districtName: "District 3 - Downtown",
            status: .onScene,
            severity: .high,
            location: Location(latitude: 33.5207, longitude: -86.8025),
            address: "I-65 N at Exit 259A",
            reportedAt: Date().addingTimeInterval(-900),
            updatedAt: Date().addingTimeInterval(-60),
            respondingUnits: [
                RespondingUnit(id: "U4", unitId: "P-45", unitName: "Patrol Unit 45", agencyType: .police, status: "On Scene", etaMinutes: nil),
                RespondingUnit(id: "U5", unitId: "M-3", unitName: "Medic 3", agencyType: .ems, status: "On Scene", etaMinutes: nil)
            ],
            notes: nil
        ),
        Incident(
            id: "INC-003",
            type: "Medical Emergency",
            description: "Cardiac arrest at shopping center",
            agencyType: .ems,
            agencyId: "BEMS-01",
            agencyName: "Birmingham EMS",
            districtId: "D-07",
            districtName: "District 7 - Eastwood",
            status: .active,
            severity: .critical,
            location: Location(latitude: 33.5089, longitude: -86.7628),
            address: "Eastwood Mall, 1600 Montclair Rd",
            reportedAt: Date().addingTimeInterval(-120),
            updatedAt: Date(),
            respondingUnits: [
                RespondingUnit(id: "U6", unitId: "M-12", unitName: "Medic 12", agencyType: .ems, status: "En Route", etaMinutes: 2)
            ],
            notes: nil
        )
    ]
}

