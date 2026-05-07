import Foundation
import SwiftUI

struct Agency: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let type: AgencyType
    let shortName: String
    let contactPhone: String?
    let contactEmail: String?
    let headquarters: String?
    let activeUnits: Int
    let totalUnits: Int
    let isConnected: Bool
    
    var availableUnits: Int {
        totalUnits - activeUnits
    }
    
    var utilizationPercentage: Double {
        guard totalUnits > 0 else { return 0 }
        return Double(activeUnits) / Double(totalUnits) * 100
    }
    
    var utilizationColor: Color {
        switch utilizationPercentage {
        case 0..<50: return .green
        case 50..<75: return .yellow
        case 75..<90: return .orange
        default: return .red
        }
    }
}

// MARK: - Sample Data

extension Agency {
    static let samples: [Agency] = [
        Agency(
            id: "SFFD-01",
            name: "San Francisco Fire Department",
            type: .fire,
            shortName: "SFFD",
            contactPhone: "(415) 558-3200",
            contactEmail: "dispatch@sffd.example",
            headquarters: "698 2nd St, San Francisco, CA",
            activeUnits: 12,
            totalUnits: 18,
            isConnected: true
        ),
        Agency(
            id: "SFPD-01",
            name: "San Francisco Police Department",
            type: .police,
            shortName: "SFPD",
            contactPhone: "(415) 553-0123",
            contactEmail: "dispatch@sfpd.example",
            headquarters: "1245 3rd St, San Francisco, CA",
            activeUnits: 45,
            totalUnits: 60,
            isConnected: true
        ),
        Agency(
            id: "SFFD-EMS-01",
            name: "San Francisco EMS",
            type: .ems,
            shortName: "SF EMS",
            contactPhone: "(415) 558-3200",
            contactEmail: "ems@sffd.example",
            headquarters: "698 2nd St, San Francisco, CA",
            activeUnits: 8,
            totalUnits: 12,
            isConnected: true
        ),
        Agency(
            id: "SFDEM-01",
            name: "San Francisco Department of Emergency Management",
            type: .emergency911,
            shortName: "SF DEM",
            contactPhone: "911",
            contactEmail: "dem@sfgov.example",
            headquarters: "1011 Turk St, San Francisco, CA",
            activeUnits: 24,
            totalUnits: 30,
            isConnected: true
        ),
        Agency(
            id: "SFMTA-01",
            name: "San Francisco Municipal Transportation Agency",
            type: .transit,
            shortName: "SFMTA",
            contactPhone: "311",
            contactEmail: "operations@sfmta.example",
            headquarters: "1 S Van Ness Ave, San Francisco, CA",
            activeUnits: 35,
            totalUnits: 50,
            isConnected: true
        )
    ]
}

