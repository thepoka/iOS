import SwiftUI

struct SettingsView: View {

    @ObservedObject var settings: TrackingSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Distance", selection: $settings.distanceFilterMeters) {
                        ForEach(TrackingSettings.distanceOptions, id: \.self) { m in
                            Text("\(Int(m)) m").tag(m)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 150)
                    .clipped()
                } header: {
                    Text("Distance Interval")
                } footer: {
                    Text("A new point is logged every \(Int(settings.distanceFilterMeters)) metre\(settings.distanceFilterMeters == 1 ? "" : "s") of movement.")
                }
            }
            .navigationTitle("Tracking Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
