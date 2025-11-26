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
            id: "BFD-01",
            name: "Birmingham Fire Department",
            type: .fire,
            shortName: "BFD",
            contactPhone: "(205) 254-2000",
            contactEmail: "dispatch@birminghamfire.gov",
            headquarters: "1808 7th Ave N, Birmingham, AL",
            activeUnits: 12,
            totalUnits: 18,
            isConnected: true
        ),
        Agency(
            id: "BPD-01",
            name: "Birmingham Police Department",
            type: .police,
            shortName: "BPD",
            contactPhone: "(205) 254-1700",
            contactEmail: "dispatch@birminghampd.gov",
            headquarters: "1710 1st Ave N, Birmingham, AL",
            activeUnits: 45,
            totalUnits: 60,
            isConnected: true
        ),
        Agency(
            id: "BEMS-01",
            name: "Birmingham Emergency Medical Services",
            type: .ems,
            shortName: "BEMS",
            contactPhone: "(205) 254-2222",
            contactEmail: "dispatch@birminghamems.gov",
            headquarters: "2100 University Blvd, Birmingham, AL",
            activeUnits: 8,
            totalUnits: 12,
            isConnected: true
        ),
        Agency(
            id: "JCC-01",
            name: "Jefferson County 911",
            type: .emergency911,
            shortName: "JC-911",
            contactPhone: "911",
            contactEmail: "admin@jc911.gov",
            headquarters: "2121 Rev Abraham Woods Jr Blvd",
            activeUnits: 24,
            totalUnits: 30,
            isConnected: true
        ),
        Agency(
            id: "BJCTA-01",
            name: "Birmingham-Jefferson County Transit Authority",
            type: .transit,
            shortName: "BJCTA",
            contactPhone: "(205) 521-0101",
            contactEmail: "operations@bjcta.org",
            headquarters: "2121 Rev Abraham Woods Jr Blvd",
            activeUnits: 35,
            totalUnits: 50,
            isConnected: true
        )
    ]
}

