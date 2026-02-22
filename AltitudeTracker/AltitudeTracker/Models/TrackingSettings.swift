import Foundation

final class TrackingSettings: ObservableObject {

    /// Minimum metres of movement before a point is logged
    @Published var distanceFilterMeters: Double {
        didSet { UserDefaults.standard.set(distanceFilterMeters, forKey: "distanceFilterMeters") }
    }

    static let distanceOptions: [Double] = [1, 3, 5, 10, 20, 50]

    init() {
        let saved = UserDefaults.standard.double(forKey: "distanceFilterMeters")
        distanceFilterMeters = saved > 0 ? saved : 5.0
    }
}
