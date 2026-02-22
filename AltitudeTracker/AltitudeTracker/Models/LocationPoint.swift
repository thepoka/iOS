import Foundation
import CoreLocation

struct LocationPoint: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let latitude: Double
    let longitude: Double
    let altitudeGPS: Double        // Altitude from GPS (meters)
    let altitudeBarometric: Double? // Altitude from barometer (more accurate, meters)
    let horizontalAccuracy: Double
    let verticalAccuracy: Double
    let speed: Double              // m/s, -1 if unavailable

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        coordinate: CLLocationCoordinate2D,
        altitudeGPS: Double,
        altitudeBarometric: Double? = nil,
        horizontalAccuracy: Double,
        verticalAccuracy: Double,
        speed: Double
    ) {
        self.id = id
        self.timestamp = timestamp
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.altitudeGPS = altitudeGPS
        self.altitudeBarometric = altitudeBarometric
        self.horizontalAccuracy = horizontalAccuracy
        self.verticalAccuracy = verticalAccuracy
        self.speed = speed
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Best available altitude: barometric if available, otherwise GPS
    var bestAltitude: Double {
        altitudeBarometric ?? altitudeGPS
    }

    var speedKmh: Double {
        speed >= 0 ? speed * 3.6 : 0
    }

    // MARK: - CSV

    static var csvHeader: String {
        "timestamp,latitude,longitude,altitude_gps_m,altitude_barometric_m,best_altitude_m,horizontal_accuracy_m,vertical_accuracy_m,speed_kmh"
    }

    var csvRow: String {
        let iso = ISO8601DateFormatter()
        let ts = iso.string(from: timestamp)
        let baro = altitudeBarometric.map { String(format: "%.2f", $0) } ?? ""
        return [
            ts,
            String(format: "%.8f", latitude),
            String(format: "%.8f", longitude),
            String(format: "%.2f", altitudeGPS),
            baro,
            String(format: "%.2f", bestAltitude),
            String(format: "%.1f", horizontalAccuracy),
            String(format: "%.1f", verticalAccuracy),
            String(format: "%.2f", speedKmh)
        ].joined(separator: ",")
    }
}
