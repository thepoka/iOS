import SwiftUI

struct ContentView: View {

    @StateObject private var locationManager = LocationManager()

    @State private var showExportSheet = false
    @State private var showClearConfirm = false
    @State private var exportFormat: ExportFormat = .csv
    @State private var exportResult: ExportResult?
    @State private var showShareSheet = false
    @State private var exportError: String?
    @State private var showPermissionAlert = false
    @State private var timerTick = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {

            // Full-screen map
            MapTrackingView(
                points: locationManager.recordedPoints,
                currentLocation: locationManager.currentPoint
            )
            .ignoresSafeArea()

            // Top bar (timestamp + GPS status)
            VStack {
                TimestampBannerView(
                    point: locationManager.currentPoint,
                    isTracking: locationManager.trackingState == .tracking
                )
                .padding(.top, 8)
                Spacer()
            }

            // Bottom controls + stats
            VStack(spacing: 12) {
                // Stats HUD (only when we have data)
                if locationManager.currentPoint != nil {
                    StatsOverlayView(
                        currentPoint: locationManager.currentPoint,
                        elevationGain: locationManager.elevationGain,
                        elevationLoss: locationManager.elevationLoss,
                        minAltitude: locationManager.minAltitude,
                        maxAltitude: locationManager.maxAltitude,
                        totalPoints: locationManager.totalPoints,
                        duration: locationManager.trackingDuration
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Control buttons
                controlBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
            }
            .animation(.spring(response: 0.4), value: locationManager.currentPoint?.id)
        }
        .onReceive(timer) { tick in timerTick = tick }
        .onAppear { locationManager.requestAuthorization() }
        .onChange(of: locationManager.authorizationStatus) { _, status in
            if status == .denied || status == .restricted {
                showPermissionAlert = true
            }
        }
        .sheet(isPresented: $showExportSheet) {
            ExportSheetView(
                points: locationManager.recordedPoints,
                onExport: handleExport
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showShareSheet) {
            if let result = exportResult {
                ShareSheet(items: [result.url])
            }
        }
        .alert("Location Permission Required", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("AltitudeTracker needs location access to track your GPS position and altitude.")
        }
        .alert("Error", isPresented: .constant(exportError != nil)) {
            Button("OK") { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
        .confirmationDialog("Clear Session", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Clear All Data", role: .destructive) {
                locationManager.clearSession()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all \(locationManager.totalPoints) recorded points from this session.")
        }
    }

    // MARK: - Control Bar

    @ViewBuilder
    private var controlBar: some View {
        HStack(spacing: 16) {

            // Clear / trash (only when there's data and not actively tracking)
            if locationManager.totalPoints > 0 && locationManager.trackingState == .idle {
                Button {
                    showClearConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.title3)
                        .foregroundStyle(.red)
                        .frame(width: 48, height: 48)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .transition(.scale.combined(with: .opacity))
            }

            Spacer()

            // Main tracking button
            trackingButton

            Spacer()

            // Export (only when there's data)
            if locationManager.totalPoints > 0 {
                Button {
                    showExportSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                        .foregroundStyle(.blue)
                        .frame(width: 48, height: 48)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3), value: locationManager.totalPoints)
        .animation(.spring(response: 0.3), value: locationManager.trackingState == .idle)
    }

    @ViewBuilder
    private var trackingButton: some View {
        switch locationManager.trackingState {
        case .idle:
            Button {
                locationManager.startTracking()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "record.circle")
                    Text("Start")
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(.red, in: Capsule())
                .foregroundStyle(.white)
                .font(.headline)
            }
            .shadow(color: .red.opacity(0.4), radius: 8, y: 4)

        case .tracking:
            HStack(spacing: 12) {
                // Pause
                Button {
                    locationManager.pauseTracking()
                } label: {
                    Image(systemName: "pause.fill")
                        .font(.title3)
                        .foregroundStyle(.orange)
                        .frame(width: 48, height: 48)
                        .background(.ultraThinMaterial, in: Circle())
                }

                // Stop
                Button {
                    locationManager.stopTracking()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "stop.circle.fill")
                        Text("Stop")
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(.primary, in: Capsule())
                    .foregroundStyle(.background)
                    .font(.headline)
                }
            }

        case .paused:
            HStack(spacing: 12) {
                // Resume
                Button {
                    locationManager.resumeTracking()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                        Text("Resume")
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(.green, in: Capsule())
                    .foregroundStyle(.white)
                    .font(.headline)
                }

                // Stop
                Button {
                    locationManager.stopTracking()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title3)
                        .foregroundStyle(.red)
                        .frame(width: 48, height: 48)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
        }
    }

    // MARK: - Export

    private func handleExport(format: ExportFormat) {
        do {
            let result = try DataExporter.export(
                points: locationManager.recordedPoints,
                format: format
            )
            exportResult = result
            showExportSheet = false
            showShareSheet = true
        } catch {
            exportError = error.localizedDescription
        }
    }
}

// MARK: - Export Sheet

struct ExportSheetView: View {
    let points: [LocationPoint]
    let onExport: (ExportFormat) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("\(points.count) recorded points")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(spacing: 12) {
                    ForEach(ExportFormat.allCases) { format in
                        Button {
                            onExport(format)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(format.rawValue)
                                        .font(.headline)
                                    Text(format == .csv
                                         ? "Best for Excel, Numbers, Google Sheets, QGIS"
                                         : "Best for apps, web services, and custom analysis")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundStyle(.blue)
                            }
                            .padding()
                            .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Export Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Share Sheet (UIActivityViewController wrapper)

import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
