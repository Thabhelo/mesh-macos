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
        id: "SF-INC-001",
        type: "Structure Fire",
        description: "Reported smoke and flames from a mixed-use building near Market Street",
        agencyType: .fire,
        agencyId: "SFFD-01",
        agencyName: "San Francisco Fire Department",
        districtId: "D-03",
        districtName: "Southern District",
        status: .responding,
        severity: .critical,
        location: Location(latitude: 37.7816, longitude: -122.4047),
        address: "5th St & Market St, San Francisco, CA",
        reportedAt: Date().addingTimeInterval(-300),
        updatedAt: Date(),
        respondingUnits: [
            RespondingUnit(id: "U1", unitId: "SFFD-E01", unitName: "Engine 1", agencyType: .fire, status: "En Route", etaMinutes: 3),
            RespondingUnit(id: "U2", unitId: "SFFD-T01", unitName: "Truck 1", agencyType: .fire, status: "En Route", etaMinutes: 5),
            RespondingUnit(id: "U3", unitId: "SFEMS-M05", unitName: "Medic 5", agencyType: .ems, status: "Staging", etaMinutes: nil)
        ],
        notes: nil
    )
    
    static let samples: [Incident] = [
        sample,
        Incident(
            id: "SF-INC-002",
            type: "Traffic Accident",
            description: "Multi-vehicle collision with injuries near the Bay Bridge approach",
            agencyType: .police,
            agencyId: "SFPD-01",
            agencyName: "San Francisco Police Department",
            districtId: "D-03",
            districtName: "Southern District",
            status: .onScene,
            severity: .high,
            location: Location(latitude: 37.7898, longitude: -122.3915),
            address: "I-80 W at 5th St, San Francisco, CA",
            reportedAt: Date().addingTimeInterval(-900),
            updatedAt: Date().addingTimeInterval(-60),
            respondingUnits: [
                RespondingUnit(id: "U4", unitId: "SFPD-3A45", unitName: "Southern Patrol 45", agencyType: .police, status: "On Scene", etaMinutes: nil),
                RespondingUnit(id: "U5", unitId: "SFEMS-M03", unitName: "Medic 3", agencyType: .ems, status: "On Scene", etaMinutes: nil)
            ],
            notes: nil
        ),
        Incident(
            id: "SF-INC-003",
            type: "Medical Emergency",
            description: "Cardiac arrest reported at a transit station concourse",
            agencyType: .ems,
            agencyId: "SFFD-EMS-01",
            agencyName: "San Francisco EMS",
            districtId: "D-02",
            districtName: "Central District",
            status: .active,
            severity: .critical,
            location: Location(latitude: 37.7844, longitude: -122.4078),
            address: "Powell St Station, San Francisco, CA",
            reportedAt: Date().addingTimeInterval(-120),
            updatedAt: Date(),
            respondingUnits: [
                RespondingUnit(id: "U6", unitId: "SFEMS-M12", unitName: "Medic 12", agencyType: .ems, status: "En Route", etaMinutes: 2)
            ],
            notes: nil
        ),
        Incident(
            id: "SF-INC-004",
            type: "Armed Robbery",
            description: "Robbery in progress reported near a retail corridor",
            agencyType: .police,
            agencyId: "SFPD-01",
            agencyName: "San Francisco Police Department",
            districtId: "D-05",
            districtName: "Tenderloin District",
            status: .active,
            severity: .critical,
            location: Location(latitude: 37.7838, longitude: -122.4131),
            address: "Eddy St & Taylor St, San Francisco, CA",
            reportedAt: Date().addingTimeInterval(-45),
            updatedAt: Date(),
            respondingUnits: [
                RespondingUnit(id: "U7", unitId: "SFPD-5B22", unitName: "Tenderloin Patrol 22", agencyType: .police, status: "En Route", etaMinutes: 1),
                RespondingUnit(id: "U8", unitId: "SFPD-5B18", unitName: "Tenderloin Patrol 18", agencyType: .police, status: "En Route", etaMinutes: 3)
            ],
            notes: nil
        ),
        Incident(
            id: "SF-INC-005",
            type: "Gas Leak",
            description: "Natural gas odor reported in a residential building",
            agencyType: .fire,
            agencyId: "SFFD-01",
            agencyName: "San Francisco Fire Department",
            districtId: "D-04",
            districtName: "Mission District",
            status: .responding,
            severity: .high,
            location: Location(latitude: 37.7599, longitude: -122.4148),
            address: "Mission St & 20th St, San Francisco, CA",
            reportedAt: Date().addingTimeInterval(-600),
            updatedAt: Date().addingTimeInterval(-30),
            respondingUnits: [
                RespondingUnit(id: "U9", unitId: "SFFD-E07", unitName: "Engine 7", agencyType: .fire, status: "En Route", etaMinutes: 4),
                RespondingUnit(id: "U10", unitId: "SFFD-HM1", unitName: "Hazmat 1", agencyType: .fire, status: "En Route", etaMinutes: 8)
            ],
            notes: nil
        ),
        Incident(
            id: "SF-INC-006",
            type: "Assault",
            description: "Assault with injuries reported near Civic Center",
            agencyType: .police,
            agencyId: "SFPD-01",
            agencyName: "San Francisco Police Department",
            districtId: "D-06",
            districtName: "Bayview District",
            status: .active,
            severity: .medium,
            location: Location(latitude: 37.7320, longitude: -122.3905),
            address: "3rd St & Palou Ave, San Francisco, CA",
            reportedAt: Date().addingTimeInterval(-180),
            updatedAt: Date(),
            respondingUnits: [
                RespondingUnit(id: "U11", unitId: "SFPD-6C31", unitName: "Bayview Patrol 31", agencyType: .police, status: "En Route", etaMinutes: 2)
            ],
            notes: nil
        ),
        Incident(
            id: "SF-INC-007",
            type: "Vehicle Fire",
            description: "Vehicle fire reported near Golden Gate Park",
            agencyType: .fire,
            agencyId: "SFFD-01",
            agencyName: "San Francisco Fire Department",
            districtId: "D-01",
            districtName: "Northern District",
            status: .responding,
            severity: .medium,
            location: Location(latitude: 37.7694, longitude: -122.4862),
            address: "Fulton St & 30th Ave, San Francisco, CA",
            reportedAt: Date().addingTimeInterval(-400),
            updatedAt: Date(),
            respondingUnits: [
                RespondingUnit(id: "U12", unitId: "SFFD-E31", unitName: "Engine 31", agencyType: .fire, status: "En Route", etaMinutes: 5)
            ],
            notes: nil
        ),
        Incident(
            id: "SF-INC-008",
            type: "Fall Injury",
            description: "Elderly person fallen with possible hip fracture",
            agencyType: .ems,
            agencyId: "SFFD-EMS-01",
            agencyName: "San Francisco EMS",
            districtId: "D-07",
            districtName: "Richmond District",
            status: .active,
            severity: .medium,
            location: Location(latitude: 37.7802, longitude: -122.4830),
            address: "Geary Blvd & 18th Ave, San Francisco, CA",
            reportedAt: Date().addingTimeInterval(-240),
            updatedAt: Date(),
            respondingUnits: [
                RespondingUnit(id: "U13", unitId: "SFEMS-M15", unitName: "Medic 15", agencyType: .ems, status: "En Route", etaMinutes: 4)
            ],
            notes: nil
        )
    ]
}

