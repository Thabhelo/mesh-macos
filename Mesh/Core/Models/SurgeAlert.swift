import Foundation
import MeshBackendCore
import SwiftUI

enum SurgeSeverity: Int, Codable, Comparable {
    case normal = 0
    case elevated = 1
    case high = 2
    case critical = 3
    
    static func < (lhs: SurgeSeverity, rhs: SurgeSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    var label: String {
        switch self {
        case .normal: return "Normal"
        case .elevated: return "Elevated"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
    
    var color: Color {
        switch self {
        case .normal: return .green
        case .elevated: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .normal: return "checkmark.circle.fill"
        case .elevated: return "exclamationmark.circle.fill"
        case .high: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.octagon.fill"
        }
    }
}

struct SurgeAlert: Identifiable, Codable, Equatable {
    let id: String
    let districtId: String
    let districtName: String
    let severity: SurgeSeverity
    let currentCallVolume: Int
    let expectedCallVolume: Int
    let percentageIncrease: Double
    let trend: SurgeTrend
    let triggeredAt: Date
    let predictedPeakTime: Date?
    let confidenceScore: Double // 0.0 to 1.0
    let contributingFactors: [String]
    
    enum SurgeTrend: String, Codable {
        case rising = "Rising"
        case stable = "Stable"
        case declining = "Declining"
        
        var icon: String {
            switch self {
            case .rising: return "arrow.up.right"
            case .stable: return "arrow.right"
            case .declining: return "arrow.down.right"
            }
        }
        
        var color: Color {
            switch self {
            case .rising: return .red
            case .stable: return .yellow
            case .declining: return .green
            }
        }
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: triggeredAt, relativeTo: Date())
    }
    
    var formattedConfidence: String {
        String(format: "%.0f%%", confidenceScore * 100)
    }
}

// MARK: - Surge Trend Data Point

struct SurgeTrendDataPoint: Identifiable, Codable {
    let id: String
    let timestamp: Date
    let callVolume: Int
    let expectedVolume: Int
    
    var variance: Double {
        guard expectedVolume > 0 else { return 0 }
        return Double(callVolume - expectedVolume) / Double(expectedVolume) * 100
    }
}

// MARK: - Sample Data

extension SurgeAlert {
    static let samples: [SurgeAlert] = [
        SurgeAlert(
            id: "SA-001",
            districtId: "D-03",
            districtName: "Southern District",
            severity: .critical,
            currentCallVolume: 45,
            expectedCallVolume: 25,
            percentageIncrease: 80,
            trend: .rising,
            triggeredAt: Date().addingTimeInterval(-1800),
            predictedPeakTime: Date().addingTimeInterval(3600),
            confidenceScore: 0.85,
            contributingFactors: ["Bay Bridge congestion", "Moscone Center event", "Evening commute"]
        ),
        SurgeAlert(
            id: "SA-002",
            districtId: "D-05",
            districtName: "Tenderloin District",
            severity: .elevated,
            currentCallVolume: 22,
            expectedCallVolume: 18,
            percentageIncrease: 22,
            trend: .stable,
            triggeredAt: Date().addingTimeInterval(-3600),
            predictedPeakTime: nil,
            confidenceScore: 0.72,
            contributingFactors: ["High call density near transit corridors"]
        ),
        SurgeAlert(
            id: "SA-003",
            districtId: "D-07",
            districtName: "Richmond District",
            severity: .high,
            currentCallVolume: 32,
            expectedCallVolume: 20,
            percentageIncrease: 60,
            trend: .rising,
            triggeredAt: Date().addingTimeInterval(-900),
            predictedPeakTime: Date().addingTimeInterval(1800),
            confidenceScore: 0.78,
            contributingFactors: ["Park event traffic", "Clustered medical calls"]
        )
    ]
}

extension SurgeAlert {
    init(wire: SurgeAlertWire) {
        self.init(
            id: wire.id,
            districtId: wire.districtId,
            districtName: wire.districtName,
            severity: SurgeSeverity(rawValue: wire.severity.rawValue) ?? .normal,
            currentCallVolume: wire.currentCallVolume,
            expectedCallVolume: wire.expectedCallVolume,
            percentageIncrease: wire.percentageIncrease,
            trend: SurgeAlert.SurgeTrend(rawValue: wire.trend.rawValue) ?? .stable,
            triggeredAt: wire.triggeredAt,
            predictedPeakTime: wire.predictedPeakTime,
            confidenceScore: wire.confidenceScore,
            contributingFactors: wire.contributingFactors
        )
    }
}

extension SurgeTrendDataPoint {
    init(wire: SurgeTrendPointWire) {
        self.init(id: wire.id, timestamp: wire.timestamp, callVolume: wire.callVolume, expectedVolume: wire.expectedVolume)
    }
}

extension SurgeTrendDataPoint {
    static func generateSampleData(hours: Int = 24) -> [SurgeTrendDataPoint] {
        var dataPoints: [SurgeTrendDataPoint] = []
        let now = Date()
        
        for i in 0..<(hours * 4) { // 15-minute intervals
            let timestamp = now.addingTimeInterval(Double(-i * 15 * 60))
            let hour = Calendar.current.component(.hour, from: timestamp)
            
            // Simulate expected volume based on time of day
            let baseExpected: Int
            switch hour {
            case 6..<9: baseExpected = 20 // Morning rush
            case 9..<12: baseExpected = 15
            case 12..<14: baseExpected = 18 // Lunch
            case 14..<17: baseExpected = 15
            case 17..<20: baseExpected = 25 // Evening rush
            case 20..<23: baseExpected = 18
            default: baseExpected = 10 // Night
            }
            
            // Deterministic demo variance keeps previews stable.
            let variance = ((i * 7) % 16) - 5
            let actual = max(0, baseExpected + variance)
            
            dataPoints.append(SurgeTrendDataPoint(
                id: "SDP-\(i)",
                timestamp: timestamp,
                callVolume: actual,
                expectedVolume: baseExpected
            ))
        }
        
        return dataPoints.reversed()
    }
}

