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
            name: "Northern District",
            shortName: "Northern",
            population: 98800,
            areaSquareMiles: 6.1,
            center: Coordinate(latitude: 37.7929, longitude: -122.4286),
            boundaries: [
                Coordinate(latitude: 37.812, longitude: -122.452),
                Coordinate(latitude: 37.812, longitude: -122.405),
                Coordinate(latitude: 37.773, longitude: -122.405),
                Coordinate(latitude: 37.773, longitude: -122.452)
            ],
            activeIncidents: 3,
            averageResponseTime: 6.2
        ),
        District(
            id: "D-02",
            name: "Central District",
            shortName: "Central",
            population: 76000,
            areaSquareMiles: 4.4,
            center: Coordinate(latitude: 37.7941, longitude: -122.4078),
            boundaries: [
                Coordinate(latitude: 37.812, longitude: -122.421),
                Coordinate(latitude: 37.812, longitude: -122.390),
                Coordinate(latitude: 37.778, longitude: -122.390),
                Coordinate(latitude: 37.778, longitude: -122.421)
            ],
            activeIncidents: 5,
            averageResponseTime: 5.8
        ),
        District(
            id: "D-03",
            name: "Southern District",
            shortName: "Southern",
            population: 97000,
            areaSquareMiles: 6.9,
            center: Coordinate(latitude: 37.7763, longitude: -122.3988),
            boundaries: [
                Coordinate(latitude: 37.790, longitude: -122.420),
                Coordinate(latitude: 37.790, longitude: -122.385),
                Coordinate(latitude: 37.750, longitude: -122.385),
                Coordinate(latitude: 37.750, longitude: -122.420)
            ],
            activeIncidents: 8,
            averageResponseTime: 4.5
        ),
        District(
            id: "D-04",
            name: "Mission District",
            shortName: "Mission",
            population: 72000,
            areaSquareMiles: 5.2,
            center: Coordinate(latitude: 37.7599, longitude: -122.4148),
            boundaries: [
                Coordinate(latitude: 37.775, longitude: -122.430),
                Coordinate(latitude: 37.775, longitude: -122.400),
                Coordinate(latitude: 37.740, longitude: -122.400),
                Coordinate(latitude: 37.740, longitude: -122.430)
            ],
            activeIncidents: 4,
            averageResponseTime: 7.3
        ),
        District(
            id: "D-05",
            name: "Tenderloin District",
            shortName: "Tenderloin",
            population: 35000,
            areaSquareMiles: 1.2,
            center: Coordinate(latitude: 37.7833, longitude: -122.4167),
            boundaries: [
                Coordinate(latitude: 37.792, longitude: -122.424),
                Coordinate(latitude: 37.792, longitude: -122.409),
                Coordinate(latitude: 37.776, longitude: -122.409),
                Coordinate(latitude: 37.776, longitude: -122.424)
            ],
            activeIncidents: 6,
            averageResponseTime: 5.1
        ),
        District(
            id: "D-06",
            name: "Bayview District",
            shortName: "Bayview",
            population: 82000,
            areaSquareMiles: 9.7,
            center: Coordinate(latitude: 37.7304, longitude: -122.3844),
            boundaries: [
                Coordinate(latitude: 37.755, longitude: -122.410),
                Coordinate(latitude: 37.755, longitude: -122.365),
                Coordinate(latitude: 37.700, longitude: -122.365),
                Coordinate(latitude: 37.700, longitude: -122.410)
            ],
            activeIncidents: 3,
            averageResponseTime: 6.8
        ),
        District(
            id: "D-07",
            name: "Richmond District",
            shortName: "Richmond",
            population: 59000,
            areaSquareMiles: 7.4,
            center: Coordinate(latitude: 37.7802, longitude: -122.4830),
            boundaries: [
                Coordinate(latitude: 37.800, longitude: -122.515),
                Coordinate(latitude: 37.800, longitude: -122.455),
                Coordinate(latitude: 37.760, longitude: -122.455),
                Coordinate(latitude: 37.760, longitude: -122.515)
            ],
            activeIncidents: 4,
            averageResponseTime: 5.5
        )
    ]
}

