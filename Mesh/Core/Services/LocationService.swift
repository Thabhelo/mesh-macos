import Foundation
import CoreLocation
import Combine

class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()
    
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isAuthorized: Bool = false
    
    private let locationManager = CLLocationManager()
    
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    // MARK: - Public Methods
    
    func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startUpdatingLocation() {
        guard isAuthorized else {
            requestAuthorization()
            return
        }
        locationManager.startUpdatingLocation()
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    func requestOneTimeLocation() {
        guard isAuthorized else {
            requestAuthorization()
            return
        }
        locationManager.requestLocation()
    }
    
    // MARK: - Distance Calculations
    
    func distance(to coordinate: CLLocationCoordinate2D) -> CLLocationDistance? {
        guard let currentLocation = currentLocation else { return nil }
        let destination = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return currentLocation.distance(from: destination)
    }
    
    func formattedDistance(to coordinate: CLLocationCoordinate2D) -> String? {
        guard let distance = distance(to: coordinate) else { return nil }
        
        let formatter = MKDistanceFormatter()
        formatter.unitStyle = .abbreviated
        return formatter.string(fromDistance: distance)
    }
    
    // MARK: - San Francisco Region
    
    static let activeRegionName = "San Francisco"
    static let activeRegionShortName = "SF"
    static let activeRegionCenter = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    static let activeRegion = CLCircularRegion(
        center: activeRegionCenter,
        radius: 18000, // Covers the San Francisco peninsula for production monitoring
        identifier: "san-francisco"
    )
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        #if os(macOS)
        isAuthorized = manager.authorizationStatus == .authorized ||
                       manager.authorizationStatus == .authorizedAlways
        #else
        isAuthorized = manager.authorizationStatus == .authorizedWhenInUse || 
                       manager.authorizationStatus == .authorizedAlways
        #endif
        
        if isAuthorized {
            startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error.localizedDescription)")
    }
}

// MARK: - MKDistanceFormatter (for formatting)

import MapKit

