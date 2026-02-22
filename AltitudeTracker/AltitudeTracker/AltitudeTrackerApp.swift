import SwiftUI

@main
struct AltitudeTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.none) // Respects system dark/light mode
        }
    }
}
