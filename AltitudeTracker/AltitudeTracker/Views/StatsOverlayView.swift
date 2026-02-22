import SwiftUI

// MARK: - Live Stats HUD (shown at the bottom while tracking)

struct StatsOverlayView: View {

    let currentPoint: LocationPoint?
    let elevationGain: Double
    let elevationLoss: Double
    let minAltitude: Double?
    let maxAltitude: Double?
    let totalPoints: Int
    let duration: TimeInterval

    @State private var isExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(.secondary.opacity(0.5))
                .frame(width: 36, height: 4)
                .padding(.top, 8)
                .onTapGesture { withAnimation(.spring()) { isExpanded.toggle() } }

            if let point = currentPoint {
                // Primary altitude display
                VStack(spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", point.bestAltitude))
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())
                        Text("m")
                            .font(.title2.bold())
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 6)
                    }

                    Text(point.altitudeBarometric != nil ? "Barometric Altitude" : "GPS Altitude")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)

                if isExpanded {
                    Divider().padding(.vertical, 8)

                    // Coordinate row
                    HStack {
                        CoordItem(
                            label: "Latitude",
                            value: String(format: "%.6f°", point.latitude)
                        )
                        Divider().frame(height: 32)
                        CoordItem(
                            label: "Longitude",
                            value: String(format: "%.6f°", point.longitude)
                        )
                    }

                    Divider().padding(.vertical, 8)

                    // Stats grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        StatCell(icon: "arrow.up.right", label: "Gain", value: String(format: "+%.0fm", elevationGain), color: .green)
                        StatCell(icon: "arrow.down.right", label: "Loss", value: String(format: "-%.0fm", elevationLoss), color: .orange)
                        StatCell(icon: "arrow.up.arrow.down", label: "Range", value: rangeText, color: .blue)
                        StatCell(icon: "location.fill", label: "Points", value: "\(totalPoints)", color: .purple)
                        StatCell(icon: "speedometer", label: "Speed", value: String(format: "%.1f km/h", point.speedKmh), color: .cyan)
                        StatCell(icon: "clock", label: "Duration", value: durationText, color: .indigo)
                    }
                    .padding(.bottom, 8)
                }

            } else {
                Text("Waiting for GPS...")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    private var rangeText: String {
        guard let lo = minAltitude, let hi = maxAltitude else { return "—" }
        return "\(Int(lo))–\(Int(hi))m"
    }

    private var durationText: String {
        let h = Int(duration) / 3600
        let m = (Int(duration) % 3600) / 60
        let s = Int(duration) % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Sub-components

struct CoordItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.footnote, design: .monospaced))
                .fontWeight(.medium)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}

struct StatCell: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.system(.footnote, design: .rounded).bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Timestamp Banner (top of screen)

struct TimestampBannerView: View {
    let point: LocationPoint?
    let isTracking: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isTracking ? .red : .gray)
                .frame(width: 8, height: 8)
                .overlay {
                    if isTracking {
                        Circle()
                            .stroke(.red.opacity(0.4), lineWidth: 2)
                            .scaleEffect(1.6)
                            .opacity(isTracking ? 1 : 0)
                    }
                }

            if let point {
                Text(point.timestamp, format: .dateTime.hour().minute().second())
                    .font(.system(.caption, design: .monospaced))
                    .contentTransition(.numericText())
                Text("·")
                    .foregroundStyle(.secondary)
                Text("±\(Int(point.horizontalAccuracy))m GPS")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(isTracking ? "Acquiring GPS…" : "Ready")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.horizontal)
    }
}
