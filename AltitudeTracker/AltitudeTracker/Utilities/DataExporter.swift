import Foundation

enum ExportFormat: String, CaseIterable, Identifiable {
    case csv = "CSV"
    case json = "JSON"

    var id: String { rawValue }
    var fileExtension: String { rawValue.lowercased() }
    var mimeType: String {
        switch self {
        case .csv: return "text/csv"
        case .json: return "application/json"
        }
    }
}

struct ExportResult {
    let url: URL
    let format: ExportFormat
    let pointCount: Int
}

enum DataExporter {

    static func export(
        points: [LocationPoint],
        format: ExportFormat,
        sessionName: String? = nil
    ) throws -> ExportResult {
        let name = sessionName ?? sessionFileName()
        let content: String

        switch format {
        case .csv:
            content = buildCSV(points: points, sessionName: name)
        case .json:
            content = try buildJSON(points: points, sessionName: name)
        }

        let filename = "\(name).\(format.fileExtension)"
        let url = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(filename)

        try content.write(to: url, atomically: true, encoding: .utf8)
        return ExportResult(url: url, format: format, pointCount: points.count)
    }

    // MARK: - CSV

    private static func buildCSV(points: [LocationPoint], sessionName: String) -> String {
        var lines = [
            "# AltitudeTracker Session: \(sessionName)",
            "# Exported: \(ISO8601DateFormatter().string(from: Date()))",
            "# Points: \(points.count)",
            "#",
            LocationPoint.csvHeader
        ]
        lines += points.map(\.csvRow)
        return lines.joined(separator: "\n")
    }

    // MARK: - JSON

    private static func buildJSON(points: [LocationPoint], sessionName: String) throws -> String {
        let payload = SessionPayload(
            session: sessionName,
            exportedAt: Date(),
            pointCount: points.count,
            points: points
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - Helpers

    private static func sessionFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return "altitude_\(formatter.string(from: Date()))"
    }
}

// MARK: - JSON Payload

private struct SessionPayload: Encodable {
    let session: String
    let exportedAt: Date
    let pointCount: Int
    let points: [LocationPoint]
}
