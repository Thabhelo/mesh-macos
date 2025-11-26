import Foundation
import SwiftUI
import CoreLocation

struct District: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let shortName: String
    let population: Int
    let areaSquareMiles: Double
    let center: Coordinate
    let boundaries: [Coordinate]
    let activeIncidents: Int
    let averageResponseTime: Double // in minutes
    
    struct Coordinate: Codable, Equatable {
        let latitude: Double
        let longitude: Double
        
        var clCoordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }
    
    var centerCoordinate: CLLocationCoordinate2D {
        center.clCoordinate
    }
    
    var boundaryCoordinates: [CLLocationCoordinate2D] {
        boundaries.map { $0.clCoordinate }
    }
    
    var incidentDensity: Double {
        guard areaSquareMiles > 0 else { return 0 }
        return Double(activeIncidents) / areaSquareMiles
    }
    
    var densityColor: Color {
        switch incidentDensity {
        case 0..<0.5: return .green
        case 0.5..<1.0: return .yellow
        case 1.0..<2.0: return .orange
        default: return .red
        }
    }
    
    var responseTimeColor: Color {
        switch averageResponseTime {
        case 0..<5: return .green
        case 5..<8: return .yellow
        case 8..<12: return .orange
        default: return .red
        }
    }
}

// MARK: - Sample Data

extension District {
    static let samples: [District] = [
        District(
            id: "D-01",
            name: "District 1 - Airport/Norwood",
            shortName: "Airport",
            population: 45000,
            areaSquareMiles: 12.5,
            center: Coordinate(latitude: 33.5651, longitude: -86.7528),
            boundaries: [
                Coordinate(latitude: 33.58, longitude: -86.78),
                Coordinate(latitude: 33.58, longitude: -86.72),
                Coordinate(latitude: 33.55, longitude: -86.72),
                Coordinate(latitude: 33.55, longitude: -86.78)
            ],
            activeIncidents: 3,
            averageResponseTime: 6.2
        ),
        District(
            id: "D-02",
            name: "District 2 - Woodlawn",
            shortName: "Woodlawn",
            population: 38000,
            areaSquareMiles: 8.3,
            center: Coordinate(latitude: 33.5461, longitude: -86.7458),
            boundaries: [
                Coordinate(latitude: 33.56, longitude: -86.77),
                Coordinate(latitude: 33.56, longitude: -86.72),
                Coordinate(latitude: 33.53, longitude: -86.72),
                Coordinate(latitude: 33.53, longitude: -86.77)
            ],
            activeIncidents: 5,
            averageResponseTime: 5.8
        ),
        District(
            id: "D-03",
            name: "District 3 - Downtown",
            shortName: "Downtown",
            population: 25000,
            areaSquareMiles: 4.2,
            center: Coordinate(latitude: 33.5207, longitude: -86.8025),
            boundaries: [
                Coordinate(latitude: 33.53, longitude: -86.82),
                Coordinate(latitude: 33.53, longitude: -86.78),
                Coordinate(latitude: 33.51, longitude: -86.78),
                Coordinate(latitude: 33.51, longitude: -86.82)
            ],
            activeIncidents: 8,
            averageResponseTime: 4.5
        ),
        District(
            id: "D-04",
            name: "District 4 - Ensley",
            shortName: "Ensley",
            population: 42000,
            areaSquareMiles: 15.6,
            center: Coordinate(latitude: 33.4978, longitude: -86.8875),
            boundaries: [
                Coordinate(latitude: 33.52, longitude: -86.92),
                Coordinate(latitude: 33.52, longitude: -86.85),
                Coordinate(latitude: 33.47, longitude: -86.85),
                Coordinate(latitude: 33.47, longitude: -86.92)
            ],
            activeIncidents: 4,
            averageResponseTime: 7.3
        ),
        District(
            id: "D-05",
            name: "District 5 - Southside",
            shortName: "Southside",
            population: 52000,
            areaSquareMiles: 6.8,
            center: Coordinate(latitude: 33.5186, longitude: -86.8104),
            boundaries: [
                Coordinate(latitude: 33.53, longitude: -86.83),
                Coordinate(latitude: 33.53, longitude: -86.79),
                Coordinate(latitude: 33.50, longitude: -86.79),
                Coordinate(latitude: 33.50, longitude: -86.83)
            ],
            activeIncidents: 6,
            averageResponseTime: 5.1
        ),
        District(
            id: "D-06",
            name: "District 6 - West End",
            shortName: "West End",
            population: 35000,
            areaSquareMiles: 9.4,
            center: Coordinate(latitude: 33.4856, longitude: -86.8356),
            boundaries: [
                Coordinate(latitude: 33.50, longitude: -86.86),
                Coordinate(latitude: 33.50, longitude: -86.81),
                Coordinate(latitude: 33.47, longitude: -86.81),
                Coordinate(latitude: 33.47, longitude: -86.86)
            ],
            activeIncidents: 3,
            averageResponseTime: 6.8
        ),
        District(
            id: "D-07",
            name: "District 7 - Eastwood",
            shortName: "Eastwood",
            population: 48000,
            areaSquareMiles: 11.2,
            center: Coordinate(latitude: 33.5089, longitude: -86.7628),
            boundaries: [
                Coordinate(latitude: 33.52, longitude: -86.79),
                Coordinate(latitude: 33.52, longitude: -86.73),
                Coordinate(latitude: 33.49, longitude: -86.73),
                Coordinate(latitude: 33.49, longitude: -86.79)
            ],
            activeIncidents: 4,
            averageResponseTime: 5.5
        )
    ]
}

