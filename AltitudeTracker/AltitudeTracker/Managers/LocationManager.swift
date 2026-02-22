import Foundation
import CoreLocation
import CoreMotion
import Combine

@MainActor
final class LocationManager: NSObject, ObservableObject {

    // MARK: - Published State

    @Published var trackingState: TrackingState = .idle
    @Published var currentPoint: LocationPoint?
    @Published var recordedPoints: [LocationPoint] = []
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?

    // MARK: - Computed Stats

    var totalPoints: Int { recordedPoints.count }

    var elevationGain: Double {
        guard recordedPoints.count > 1 else { return 0 }
        var gain = 0.0
        for i in 1..<recordedPoints.count {
            let delta = recordedPoints[i].bestAltitude - recordedPoints[i - 1].bestAltitude
            if delta > 0 { gain += delta }
        }
        return gain
    }

    var elevationLoss: Double {
        guard recordedPoints.count > 1 else { return 0 }
        var loss = 0.0
        for i in 1..<recordedPoints.count {
            let delta = recordedPoints[i].bestAltitude - recordedPoints[i - 1].bestAltitude
            if delta < 0 { loss += abs(delta) }
        }
        return loss
    }

    var minAltitude: Double? { recordedPoints.map(\.bestAltitude).min() }
    var maxAltitude: Double? { recordedPoints.map(\.bestAltitude).max() }

    var trackingDuration: TimeInterval {
        guard let first = recordedPoints.first?.timestamp,
              let last = recordedPoints.last?.timestamp else { return 0 }
        return last.timeIntervalSince(first)
    }

    // MARK: - Private

    private let clManager = CLLocationManager()
    private let altimeter = CMAltimeter()
    private var latestBarometricAltitude: Double?
    private var sessionStart: Date?

    enum TrackingState {
        case idle, tracking, paused
    }

    // MARK: - Init

    override init() {
        super.init()
        clManager.delegate = self
        clManager.desiredAccuracy = kCLLocationAccuracyBest
        clManager.distanceFilter = 5 // record every 5 meters of movement
        clManager.activityType = .fitness
        authorizationStatus = clManager.authorizationStatus
    }

    // MARK: - Public API

    func requestAuthorization() {
        clManager.requestWhenInUseAuthorization()
    }

    func startTracking() {
        recordedPoints = []
        sessionStart = Date()
        trackingState = .tracking
        clManager.startUpdatingLocation()
        startBarometer()
    }

    func stopTracking() {
        trackingState = .idle
        clManager.stopUpdatingLocation()
        stopBarometer()
    }

    func pauseTracking() {
        trackingState = .paused
        clManager.stopUpdatingLocation()
        stopBarometer()
    }

    func resumeTracking() {
        trackingState = .tracking
        clManager.startUpdatingLocation()
        startBarometer()
    }

    func clearSession() {
        recordedPoints = []
        currentPoint = nil
        sessionStart = nil
        latestBarometricAltitude = nil
    }

    // MARK: - Barometer

    private func startBarometer() {
        guard CMAltimeter.isRelativeAltitudeAvailable() else { return }
        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, error in
            guard let self, let data, error == nil else { return }
            // relativeAltitude is relative to session start; add GPS baseline
            let baseGPS = self.recordedPoints.first?.altitudeGPS ?? 0
            self.latestBarometricAltitude = baseGPS + data.relativeAltitude.doubleValue
        }
    }

    private func stopBarometer() {
        altimeter.stopRelativeAltitudeUpdates()
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        // Filter out inaccurate readings
        guard location.horizontalAccuracy >= 0,
              location.horizontalAccuracy < 50 else { return }

        Task { @MainActor in
            let point = LocationPoint(
                coordinate: location.coordinate,
                altitudeGPS: location.altitude,
                altitudeBarometric: self.latestBarometricAltitude,
                horizontalAccuracy: location.horizontalAccuracy,
                verticalAccuracy: location.verticalAccuracy,
                speed: location.speed
            )

            self.currentPoint = point

            if self.trackingState == .tracking {
                self.recordedPoints.append(point)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.errorMessage = error.localizedDescription
        }
    }
}
