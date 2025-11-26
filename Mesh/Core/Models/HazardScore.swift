import Foundation
import SwiftUI

struct HazardScore: Identifiable, Codable, Equatable {
    let id: String
    let overallScore: Int // 0-100
    let lastUpdated: Date
    let components: HazardComponents
    let historicalComparison: HistoricalComparison
    let districtScores: [DistrictHazardScore]
    
    struct HazardComponents: Codable, Equatable {
        let weather: ComponentScore
        let traffic: ComponentScore
        let incidentActivity: ComponentScore
        let infrastructureOutages: ComponentScore
        let specialEvents: ComponentScore
        
        var allComponents: [(name: String, score: ComponentScore)] {
            [
                ("Weather", weather),
                ("Traffic", traffic),
                ("Incident Activity", incidentActivity),
                ("Infrastructure", infrastructureOutages),
                ("Special Events", specialEvents)
            ]
        }
    }
    
    struct ComponentScore: Codable, Equatable {
        let score: Int // 0-100
        let weight: Double // 0.0-1.0
        let trend: Trend
        let details: String
        
        enum Trend: String, Codable {
            case improving = "Improving"
            case stable = "Stable"
            case worsening = "Worsening"
            
            var icon: String {
                switch self {
                case .improving: return "arrow.down.right"
                case .stable: return "arrow.right"
                case .worsening: return "arrow.up.right"
                }
            }
            
            var color: Color {
                switch self {
                case .improving: return .green
                case .stable: return .yellow
                case .worsening: return .red
                }
            }
        }
        
        var weightedScore: Double {
            Double(score) * weight
        }
        
        var color: Color {
            switch score {
            case 0..<25: return .green
            case 25..<50: return .yellow
            case 50..<75: return .orange
            default: return .red
            }
        }
    }
    
    struct HistoricalComparison: Codable, Equatable {
        let yesterdayScore: Int
        let lastWeekAverage: Int
        let lastMonthAverage: Int
        
        func changeFrom(_ baseline: Int, current: Int) -> Int {
            current - baseline
        }
    }
    
    struct DistrictHazardScore: Identifiable, Codable, Equatable {
        let id: String
        let districtId: String
        let districtName: String
        let score: Int
        let primaryRisk: String
        
        var color: Color {
            switch score {
            case 0..<25: return .green
            case 25..<50: return .yellow
            case 50..<75: return .orange
            default: return .red
            }
        }
    }
    
    var statusColor: Color {
        switch overallScore {
        case 0..<25: return .green
        case 25..<50: return .yellow
        case 50..<75: return .orange
        default: return .red
        }
    }
    
    var statusLabel: String {
        switch overallScore {
        case 0..<25: return "Low Risk"
        case 25..<50: return "Moderate Risk"
        case 50..<75: return "Elevated Risk"
        default: return "High Risk"
        }
    }
    
    var changeFromYesterday: Int {
        overallScore - historicalComparison.yesterdayScore
    }
}

// MARK: - Sample Data

extension HazardScore {
    static let sample = HazardScore(
        id: "HS-001",
        overallScore: 58,
        lastUpdated: Date(),
        components: HazardComponents(
            weather: ComponentScore(
                score: 65,
                weight: 0.25,
                trend: .worsening,
                details: "Severe thunderstorm watch in effect until 10 PM"
            ),
            traffic: ComponentScore(
                score: 72,
                weight: 0.20,
                trend: .stable,
                details: "Heavy congestion on I-65 and I-20/59 interchange"
            ),
            incidentActivity: ComponentScore(
                score: 55,
                weight: 0.30,
                trend: .stable,
                details: "Above average call volume in Districts 3 and 5"
            ),
            infrastructureOutages: ComponentScore(
                score: 25,
                weight: 0.15,
                trend: .improving,
                details: "Minor power outage in Ensley area being addressed"
            ),
            specialEvents: ComponentScore(
                score: 80,
                weight: 0.10,
                trend: .stable,
                details: "UAB football game at Protective Stadium (45,000 expected)"
            )
        ),
        historicalComparison: HistoricalComparison(
            yesterdayScore: 42,
            lastWeekAverage: 48,
            lastMonthAverage: 45
        ),
        districtScores: [
            DistrictHazardScore(id: "DHS-01", districtId: "D-01", districtName: "Airport", score: 35, primaryRisk: "Traffic"),
            DistrictHazardScore(id: "DHS-02", districtId: "D-02", districtName: "Woodlawn", score: 42, primaryRisk: "Incidents"),
            DistrictHazardScore(id: "DHS-03", districtId: "D-03", districtName: "Downtown", score: 78, primaryRisk: "Special Event"),
            DistrictHazardScore(id: "DHS-04", districtId: "D-04", districtName: "Ensley", score: 48, primaryRisk: "Infrastructure"),
            DistrictHazardScore(id: "DHS-05", districtId: "D-05", districtName: "Southside", score: 62, primaryRisk: "Traffic"),
            DistrictHazardScore(id: "DHS-06", districtId: "D-06", districtName: "West End", score: 38, primaryRisk: "Weather"),
            DistrictHazardScore(id: "DHS-07", districtId: "D-07", districtName: "Eastwood", score: 55, primaryRisk: "Incidents")
        ]
    )
}

