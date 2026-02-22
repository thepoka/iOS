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
    @State private var showSettings = false
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

            // Settings gear — top-right corner, only available when idle
            VStack {
                HStack {
                    Spacer()
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(
                                locationManager.trackingState == .idle
                                ? Color.primary
                                : Color.primary.opacity(0.25)
                            )
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .disabled(locationManager.trackingState != .idle)
                    .padding(.top, 16)
                    .padding(.trailing, 16)
                }
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
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: locationManager.settings)
                .presentationDetents([.medium])
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
    //
    // Fixed 3-slot layout so the centre button never moves:
    //   [left circle]   [── centre capsule ──]   [right circle]
    //
    // idle:     trash (if data) | START  | export (if data)
    // tracking: stop            | PAUSE  | export (if data)
    // paused:   stop            | RESUME | export (if data)

    private var controlBar: some View {
        HStack(spacing: 0) {

            // LEFT slot — always 56 pt wide
            leftButton
                .frame(width: 56, height: 56)

            Spacer()

            // CENTRE — morphs between Start / Pause / Resume
            centreCapsuleButton

            Spacer()

            // RIGHT slot — always 56 pt wide
            rightButton
                .frame(width: 56, height: 56)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8),
                   value: locationManager.trackingState == .idle)
        .animation(.spring(response: 0.35, dampingFraction: 0.8),
                   value: locationManager.totalPoints)
    }

    // Centre capsule: label & colour change, position stays fixed
    private var centreCapsuleButton: some View {
        let config = centreButtonConfig
        return Button(action: config.action) {
            HStack(spacing: 8) {
                Image(systemName: config.icon)
                Text(config.label)
                    .fontWeight(.semibold)
            }
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 15)
            .background(config.color, in: Capsule())
            .shadow(color: config.color.opacity(0.45), radius: 10, y: 4)
        }
        .contentTransition(.symbolEffect(.replace))
        .animation(.spring(response: 0.3), value: locationManager.trackingState == .idle)
    }

    private struct CentreButtonConfig {
        let icon: String
        let label: String
        let color: Color
        let action: () -> Void
    }

    private var centreButtonConfig: CentreButtonConfig {
        switch locationManager.trackingState {
        case .idle:
            return CentreButtonConfig(icon: "record.circle", label: "Start",
                                      color: .red, action: locationManager.startTracking)
        case .tracking:
            return CentreButtonConfig(icon: "pause.fill", label: "Pause",
                                      color: .orange, action: locationManager.pauseTracking)
        case .paused:
            return CentreButtonConfig(icon: "play.fill", label: "Resume",
                                      color: .green, action: locationManager.resumeTracking)
        }
    }

    // Left slot: trash when idle+data, stop when active
    @ViewBuilder
    private var leftButton: some View {
        switch locationManager.trackingState {
        case .idle:
            if locationManager.totalPoints > 0 {
                Button { showClearConfirm = true } label: {
                    circleIcon("trash", color: .red)
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                Color.clear  // invisible placeholder — keeps layout stable
            }
        case .tracking, .paused:
            Button(action: locationManager.stopTracking) {
                circleIcon("stop.fill", color: .red)
            }
            .transition(.scale.combined(with: .opacity))
        }
    }

    // Right slot: export when there is data
    @ViewBuilder
    private var rightButton: some View {
        if locationManager.totalPoints > 0 {
            Button { showExportSheet = true } label: {
                circleIcon("square.and.arrow.up", color: .blue)
            }
            .transition(.scale.combined(with: .opacity))
        } else {
            Color.clear
        }
    }

    private func circleIcon(_ name: String, color: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(color)
            .frame(width: 52, height: 52)
            .background(.ultraThinMaterial, in: Circle())
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
