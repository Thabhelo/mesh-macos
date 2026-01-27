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
        ),
        Incident(
            id: "INC-004",
            type: "Armed Robbery",
            description: "Robbery in progress at convenience store",
            agencyType: .police,
            agencyId: "BPD-02",
            agencyName: "Birmingham Police Department",
            districtId: "D-02",
            districtName: "District 2 - North Birmingham",
            status: .active,
            severity: .critical,
            location: Location(latitude: 33.5398, longitude: -86.8189),
            address: "2456 32nd Ave N, Birmingham, AL 35207",
            reportedAt: Date().addingTimeInterval(-45),
            updatedAt: Date(),
            respondingUnits: [
                RespondingUnit(id: "U7", unitId: "P-22", unitName: "Patrol Unit 22", agencyType: .police, status: "En Route", etaMinutes: 1),
                RespondingUnit(id: "U8", unitId: "P-18", unitName: "Patrol Unit 18", agencyType: .police, status: "En Route", etaMinutes: 3)
            ],
            notes: nil
        ),
        Incident(
            id: "INC-005",
            type: "Gas Leak",
            description: "Natural gas leak reported at apartment complex",
            agencyType: .fire,
            agencyId: "BFD-02",
            agencyName: "Birmingham Fire Department",
            districtId: "D-04",
            districtName: "District 4 - Ensley",
            status: .responding,
            severity: .high,
            location: Location(latitude: 33.5246, longitude: -86.8693),
            address: "1789 Avenue F, Birmingham, AL 35218",
            reportedAt: Date().addingTimeInterval(-600),
            updatedAt: Date().addingTimeInterval(-30),
            respondingUnits: [
                RespondingUnit(id: "U9", unitId: "E-5", unitName: "Engine 5", agencyType: .fire, status: "En Route", etaMinutes: 4),
                RespondingUnit(id: "U10", unitId: "HAZ-1", unitName: "Hazmat 1", agencyType: .fire, status: "En Route", etaMinutes: 8)
            ],
            notes: nil
        ),
        Incident(
            id: "INC-006",
            type: "Assault",
            description: "Domestic disturbance with injuries",
            agencyType: .police,
            agencyId: "BPD-03",
            agencyName: "Birmingham Police Department",
            districtId: "D-06",
            districtName: "District 6 - West End",
            status: .active,
            severity: .medium,
            location: Location(latitude: 33.5123, longitude: -86.8456),
            address: "5678 3rd Ave W, Birmingham, AL 35208",
            reportedAt: Date().addingTimeInterval(-180),
            updatedAt: Date(),
            respondingUnits: [
                RespondingUnit(id: "U11", unitId: "P-31", unitName: "Patrol Unit 31", agencyType: .police, status: "En Route", etaMinutes: 2)
            ],
            notes: nil
        ),
        Incident(
            id: "INC-007",
            type: "Vehicle Fire",
            description: "Car fire in parking lot",
            agencyType: .fire,
            agencyId: "BFD-03",
            agencyName: "Birmingham Fire Department",
            districtId: "D-01",
            districtName: "District 1 - Central",
            status: .responding,
            severity: .medium,
            location: Location(latitude: 33.5276, longitude: -86.7989),
            address: "3200 University Blvd, Birmingham, AL 35233",
            reportedAt: Date().addingTimeInterval(-400),
            updatedAt: Date(),
            respondingUnits: [
                RespondingUnit(id: "U12", unitId: "E-2", unitName: "Engine 2", agencyType: .fire, status: "En Route", etaMinutes: 5)
            ],
            notes: nil
        ),
        Incident(
            id: "INC-008",
            type: "Fall Injury",
            description: "Elderly person fallen, possible hip fracture",
            agencyType: .ems,
            agencyId: "BEMS-02",
            agencyName: "Birmingham EMS",
            districtId: "D-08",
            districtName: "District 8 - Mountain Brook",
            status: .active,
            severity: .medium,
            location: Location(latitude: 33.4890, longitude: -86.7445),
            address: "2801 Cahaba Rd, Mountain Brook, AL 35223",
            reportedAt: Date().addingTimeInterval(-240),
            updatedAt: Date(),
            respondingUnits: [
                RespondingUnit(id: "U13", unitId: "M-15", unitName: "Medic 15", agencyType: .ems, status: "En Route", etaMinutes: 4)
            ],
            notes: nil
        ),
        Incident(
            id: "INC-009",
            type: "Burglary",
            description: "Break-in at retail store",
            agencyType: .police,
            agencyId: "BPD-04",
            agencyName: "Birmingham Police Department",
            districtId: "D-05",
            districtName: "District 5 - Southside",
            status: .active,
            severity: .high,
            location: Location(latitude: 33.5098, longitude: -86.8034),
            address: "1456 10th Ave S, Birmingham, AL 35205",
            reportedAt: Date().addingTimeInterval(-90),
            updatedAt: Date(),
            respondingUnits: [
                RespondingUnit(id: "U14", unitId: "P-52", unitName: "Patrol Unit 52", agencyType: .police, status: "En Route", etaMinutes: 3)
            ],
            notes: nil
        ),
        Incident(
            id: "INC-010",
            type: "Transit Emergency",
            description: "Bus accident with passenger injuries",
            agencyType: .transit,
            agencyId: "MAX-01",
            agencyName: "Birmingham Transit Authority",
            districtId: "D-03",
            districtName: "District 3 - Downtown",
            status: .responding,
            severity: .high,
            location: Location(latitude: 33.5154, longitude: -86.8098),
            address: "20th Street N at 5th Ave N",
            reportedAt: Date().addingTimeInterval(-150),
            updatedAt: Date(),
            respondingUnits: [
                RespondingUnit(id: "U15", unitId: "M-8", unitName: "Medic 8", agencyType: .ems, status: "En Route", etaMinutes: 2),
                RespondingUnit(id: "U16", unitId: "P-12", unitName: "Patrol Unit 12", agencyType: .police, status: "On Scene", etaMinutes: nil)
            ],
            notes: nil
        ),
        Incident(
            id: "INC-011",
            type: "Overdose",
            description: "Suspected opioid overdose, patient unconscious",
            agencyType: .ems,
            agencyId: "BEMS-03",
            agencyName: "Birmingham EMS",
            districtId: "D-02",
            districtName: "District 2 - North Birmingham",
            status: .active,
            severity: .critical,
            location: Location(latitude: 33.5445, longitude: -86.8223),
            address: "945 Graymont Ave W, Birmingham, AL 35204",
            reportedAt: Date().addingTimeInterval(-75),
            updatedAt: Date(),
            respondingUnits: [
                RespondingUnit(id: "U17", unitId: "M-5", unitName: "Medic 5", agencyType: .ems, status: "En Route", etaMinutes: 1)
            ],
            notes: nil
        ),
        Incident(
            id: "INC-012",
            type: "Hazmat Spill",
            description: "Chemical spill at industrial site",
            agencyType: .fire,
            agencyId: "BFD-04",
            agencyName: "Birmingham Fire Department",
            districtId: "D-04",
            districtName: "District 4 - Ensley",
            status: .responding,
            severity: .critical,
            location: Location(latitude: 33.5312, longitude: -86.8845),
            address: "Industrial Park Rd, Birmingham, AL 35218",
            reportedAt: Date().addingTimeInterval(-200),
            updatedAt: Date(),
            respondingUnits: [
                RespondingUnit(id: "U18", unitId: "HAZ-1", unitName: "Hazmat 1", agencyType: .fire, status: "En Route", etaMinutes: 6),
                RespondingUnit(id: "U19", unitId: "E-9", unitName: "Engine 9", agencyType: .fire, status: "En Route", etaMinutes: 4)
            ],
            notes: nil
        ),
        Incident(
            id: "INC-013",
            type: "Shooting",
            description: "Gunshot wound victim at residence",
            agencyType: .police,
            agencyId: "BPD-05",
            agencyName: "Birmingham Police Department",
            districtId: "D-06",
            districtName: "District 6 - West End",
            status: .active,
            severity: .critical,
            location: Location(latitude: 33.5089, longitude: -86.8534),
            address: "1234 Avenue W, Birmingham, AL 35208",
            reportedAt: Date().addingTimeInterval(-55),
            updatedAt: Date(),
            respondingUnits: [
                RespondingUnit(id: "U20", unitId: "P-28", unitName: "Patrol Unit 28", agencyType: .police, status: "En Route", etaMinutes: 2),
                RespondingUnit(id: "U21", unitId: "M-11", unitName: "Medic 11", agencyType: .ems, status: "Staging", etaMinutes: nil)
            ],
            notes: nil
        ),
        Incident(
            id: "INC-014",
            type: "Structure Collapse",
            description: "Partial building collapse at construction site",
            agencyType: .fire,
            agencyId: "BFD-05",
            agencyName: "Birmingham Fire Department",
            districtId: "D-01",
            districtName: "District 1 - Central",
            status: .active,
            severity: .critical,
            location: Location(latitude: 33.5234, longitude: -86.7956),
            address: "1800 4th Ave N, Birmingham, AL 35203",
            reportedAt: Date().addingTimeInterval(-30),
            updatedAt: Date(),
            respondingUnits: [
                RespondingUnit(id: "U22", unitId: "E-1", unitName: "Engine 1", agencyType: .fire, status: "En Route", etaMinutes: 2),
                RespondingUnit(id: "U23", unitId: "R-1", unitName: "Rescue 1", agencyType: .fire, status: "En Route", etaMinutes: 3),
                RespondingUnit(id: "U24", unitId: "M-2", unitName: "Medic 2", agencyType: .ems, status: "En Route", etaMinutes: 3)
            ],
            notes: nil
        ),
        Incident(
            id: "INC-015",
            type: "Assault with Weapon",
            description: "Stabbing at nightclub",
            agencyType: .police,
            agencyId: "BPD-06",
            agencyName: "Birmingham Police Department",
            districtId: "D-05",
            districtName: "District 5 - Southside",
            status: .active,
            severity: .high,
            location: Location(latitude: 33.5145, longitude: -86.8112),
            address: "1923 11th Ave S, Birmingham, AL 35205",
            reportedAt: Date().addingTimeInterval(-100),
            updatedAt: Date(),
            respondingUnits: [
                RespondingUnit(id: "U25", unitId: "P-55", unitName: "Patrol Unit 55", agencyType: .police, status: "On Scene", etaMinutes: nil),
                RespondingUnit(id: "U26", unitId: "M-14", unitName: "Medic 14", agencyType: .ems, status: "En Route", etaMinutes: 1)
            ],
            notes: nil
        )
    ]
}

