import Foundation
import CoreLocation

/// Singleton LocationManager for requesting and tracking GPS coordinates
@MainActor
class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()

    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var lastKnownLocation: CLLocationCoordinate2D?

    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters // Good enough for meter readings
        authorizationStatus = locationManager.authorizationStatus
    }

    /// Request location permission if not already granted
    func requestPermission() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            print("[LocationManager] Location permission denied or restricted")
        case .authorizedWhenInUse, .authorizedAlways:
            print("[LocationManager] Location permission already granted")
        @unknown default:
            break
        }
    }

    /// Get current location asynchronously
    /// Returns nil if location unavailable or permission denied
    func getCurrentLocation() async -> CLLocationCoordinate2D? {
        // Check authorization status
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            print("[LocationManager] Location permission not granted")
            return lastKnownLocation
        }

        // Request location update
        return await withCheckedContinuation { continuation in
            locationContinuation = continuation
            locationManager.requestLocation()
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            print("[LocationManager] Authorization status changed: \(authorizationStatus.rawValue)")
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.last else { return }

            let coordinate = location.coordinate
            lastKnownLocation = coordinate
            print("[LocationManager] Location updated: \(coordinate.latitude), \(coordinate.longitude)")

            // Resolve continuation if waiting
            locationContinuation?.resume(returning: coordinate)
            locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            print("[LocationManager] Location error: \(error.localizedDescription)")

            // Return last known location or nil
            locationContinuation?.resume(returning: lastKnownLocation)
            locationContinuation = nil
        }
    }
}
