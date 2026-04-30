import Foundation

enum MachineStatus: String {
    case idle = "IDLE"
    case printing = "PRINTING"
    case paused = "PAUSED"
    case error = "ERROR"
    case unknown = "UNKNOWN"

    init(raw: String) {
        self = MachineStatus(rawValue: raw.uppercased()) ?? .unknown
    }

    var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .printing: return "Printing"
        case .paused: return "Paused"
        case .error: return "Error"
        case .unknown: return "Unknown"
        }
    }
}

struct TemperatureReading: Codable {
    let current: Double
    let target: Double
}

struct PrintProgress {
    let completion: Double
    let printTime: Int
    let printTimeLeft: Int
    let filamentUsed: Double
}

struct MachineState {
    var status: MachineStatus = .unknown
    var fileName: String = ""
    var progress: PrintProgress?
    var extruder: TemperatureReading?
    var heatedBed: TemperatureReading?
    var x: Double = 0
    var y: Double = 0
    var z: Double = 0
    var updatedAt: Date = Date()

    var isActive: Bool { status == .printing || status == .paused }
    var completionPct: Double { progress?.completion ?? 0 }

    var timeLeftFormatted: String {
        guard let s = progress?.printTimeLeft, s > 0 else { return "--" }
        let h = s / 3600, m = (s % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    var elapsedFormatted: String {
        guard let s = progress?.printTime, s > 0 else { return "--" }
        let h = s / 3600, m = (s % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    var shortFileName: String {
        guard !fileName.isEmpty else { return "No file" }
        return URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
    }
}

// MARK: - API Response Types

struct ConnectResponse: Codable {
    let token: String
}

struct SnapmakerStatusResponse: Codable {
    let status: String?
    let x: Double?
    let y: Double?
    let z: Double?
    let temperature: TempData?
    let progress: ProgressData?
    let fileName: String?

    struct TempData: Codable {
        let extruder: TemperatureReading?
        let heatedBed: TemperatureReading?
    }

    struct ProgressData: Codable {
        let completion: Double?
        let printTime: Int?
        let printTimeLeft: Int?
        let filamentUsed: Double?
    }

    func toMachineState() -> MachineState {
        var s = MachineState()
        s.status = MachineStatus(raw: status ?? "UNKNOWN")
        s.x = x ?? 0
        s.y = y ?? 0
        s.z = z ?? 0
        s.fileName = fileName ?? ""
        s.extruder = temperature?.extruder
        s.heatedBed = temperature?.heatedBed
        if let p = progress {
            s.progress = PrintProgress(
                completion: p.completion ?? 0,
                printTime: p.printTime ?? 0,
                printTimeLeft: p.printTimeLeft ?? 0,
                filamentUsed: p.filamentUsed ?? 0
            )
        }
        s.updatedAt = Date()
        return s
    }
}
