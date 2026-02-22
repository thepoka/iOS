import SwiftUI
import MapKit

// MARK: - Altitude Annotation

struct AltitudeAnnotation: Identifiable, Hashable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let altitude: Double
    let isStart: Bool
    let isEnd: Bool

    // Hashable using only id — CLLocationCoordinate2D is not Hashable
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: AltitudeAnnotation, rhs: AltitudeAnnotation) -> Bool { lhs.id == rhs.id }
}

// MARK: - MapTrackingView

struct MapTrackingView: View {

    let points: [LocationPoint]
    let currentLocation: LocationPoint?

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedAnnotation: AltitudeAnnotation?

    // Sample every N points for altitude pin annotations (avoid clutter)
    private var annotationPoints: [AltitudeAnnotation] {
        guard !points.isEmpty else { return [] }
        var result: [AltitudeAnnotation] = []

        // Always show start
        if let first = points.first {
            result.append(AltitudeAnnotation(
                id: first.id,
                coordinate: first.coordinate,
                altitude: first.bestAltitude,
                isStart: true,
                isEnd: false
            ))
        }

        // Sample intermediate points (every 10th or at local extremes)
        let stride = max(1, points.count / 10)
        for i in Swift.stride(from: stride, to: points.count - 1, by: stride) {
            let p = points[i]
            result.append(AltitudeAnnotation(
                id: p.id,
                coordinate: p.coordinate,
                altitude: p.bestAltitude,
                isStart: false,
                isEnd: false
            ))
        }

        // Always show end (if different from start)
        if points.count > 1, let last = points.last {
            result.append(AltitudeAnnotation(
                id: last.id,
                coordinate: last.coordinate,
                altitude: last.bestAltitude,
                isStart: false,
                isEnd: true
            ))
        }

        return result
    }

    private var routeCoordinates: [CLLocationCoordinate2D] {
        points.map(\.coordinate)
    }

    var body: some View {
        Map(position: $cameraPosition, selection: $selectedAnnotation) {

            // Current user location pulsing dot
            UserAnnotation()

            // Route polyline
            if routeCoordinates.count > 1 {
                MapPolyline(coordinates: routeCoordinates)
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .cyan, .green],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 4
                    )
            }

            // Altitude annotations
            ForEach(annotationPoints) { ann in
                Annotation(
                    altitudeLabel(ann),
                    coordinate: ann.coordinate,
                    anchor: .bottom
                ) {
                    AltitudePinView(annotation: ann)
                }
                .tag(ann)
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .mapControls {
            MapCompass()
            MapUserLocationButton()
            MapScaleView()
        }
        .onChange(of: currentLocation) { _, newLocation in
            guard let loc = newLocation else { return }
            withAnimation(.easeInOut(duration: 0.5)) {
                cameraPosition = .camera(MapCamera(
                    centerCoordinate: loc.coordinate,
                    distance: 500,
                    heading: 0,
                    pitch: 45
                ))
            }
        }
        .overlay(alignment: .top) {
            if let selected = selectedAnnotation {
                AnnotationDetailBubble(annotation: selected)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(), value: selectedAnnotation?.id)
    }

    private func altitudeLabel(_ ann: AltitudeAnnotation) -> String {
        if ann.isStart { return "Start" }
        if ann.isEnd { return "End" }
        return "\(Int(ann.altitude))m"
    }
}

// MARK: - Altitude Pin

struct AltitudePinView: View {
    let annotation: AltitudeAnnotation

    private var pinColor: Color {
        if annotation.isStart { return .green }
        if annotation.isEnd { return .red }
        return .blue
    }

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(pinColor)
                    .frame(width: 28, height: 28)
                    .shadow(radius: 3)

                if annotation.isStart {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                } else if annotation.isEnd {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                } else {
                    Text("\(Int(annotation.altitude))m")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                }
            }

            // Pin tail
            Triangle()
                .fill(pinColor)
                .frame(width: 8, height: 6)
        }
    }
}

// MARK: - Annotation Detail Bubble

struct AnnotationDetailBubble: View {
    let annotation: AltitudeAnnotation

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(annotation.isStart ? "Start Point" : annotation.isEnd ? "End Point" : "Waypoint")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text("\(String(format: "%.1f", annotation.altitude)) m")
                    .font(.title3.bold())
            }
            Divider()
            VStack(alignment: .leading, spacing: 2) {
                Text("Lat")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(String(format: "%.5f°", annotation.coordinate.latitude))
                    .font(.caption.monospacedDigit())
                Text("Lon")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(String(format: "%.5f°", annotation.coordinate.longitude))
                    .font(.caption.monospacedDigit())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

// MARK: - Triangle Shape (pin tail)

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
