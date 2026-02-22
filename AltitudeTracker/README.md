# AltitudeTracker

An iOS app for recording GPS altitude, coordinates, and routes with an Apple Maps overlay.

## Features

- Full-screen Apple Maps with 3D realistic terrain
- Live polyline showing your route (blue → cyan → green gradient)
- Altitude pins with start/end markers and sampled waypoints
- Dual altitude source: GPS + barometric altimeter (more accurate)
- Stats HUD: elevation gain/loss, speed, min/max altitude, duration
- Export as **CSV** (recommended) or **JSON**
- Share via AirDrop, Files, email, or any app

## Setup in Xcode

1. Open Xcode → **File > Open** → select `AltitudeTracker/` folder
   - Or create a new Xcode project named `AltitudeTracker` and copy the Swift files in
2. Set your **Bundle Identifier** and **Team** in Signing & Capabilities
3. The `Info.plist` is pre-configured with all required permission strings
4. Enable **Background Modes → Location updates** in Signing & Capabilities
5. Run on a **physical device** (GPS does not work in Simulator)

## Minimum Requirements

- iOS 17.0+
- Xcode 15.0+
- Physical iPhone with GPS (A-GPS or better)
- Optional: barometric altimeter (iPhone 6+)

## File Structure

```
AltitudeTracker/
├── AltitudeTrackerApp.swift        # App entry point (@main)
├── Info.plist                      # Permissions & background modes
├── Models/
│   └── LocationPoint.swift         # Data model + CSV/JSON serialization
├── Managers/
│   └── LocationManager.swift       # CoreLocation + CoreMotion (barometer)
├── Views/
│   ├── ContentView.swift           # Main UI, controls, export sheet
│   ├── MapTrackingView.swift       # MapKit map + polyline + annotations
│   └── StatsOverlayView.swift      # Altitude HUD + stats grid
└── Utilities/
    └── DataExporter.swift          # CSV & JSON export to temp file
```

## CSV Format

```
timestamp,latitude,longitude,altitude_gps_m,altitude_barometric_m,best_altitude_m,horizontal_accuracy_m,vertical_accuracy_m,speed_kmh
2024-06-01T09:00:00Z,51.500729,-0.124625,12.50,11.80,11.80,4.1,3.2,5.40
```

Open directly in Excel, Numbers, Google Sheets, or import into QGIS/Google Earth.

## Why CSV over JSON?

| | CSV | JSON |
|---|---|---|
| Excel / Numbers | ✅ Native | ❌ Needs conversion |
| Google Sheets | ✅ Direct import | ⚠️ Manual |
| QGIS / GIS tools | ✅ Direct | ⚠️ GeoJSON only |
| Custom code | ✅ Easy | ✅ Easy |
| File size | ✅ Smaller | ❌ ~3x larger |

Both formats are exported — choose based on your workflow.
