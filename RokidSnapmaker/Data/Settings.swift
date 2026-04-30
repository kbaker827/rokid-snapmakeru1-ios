import Foundation

enum GlassesFormat: String, CaseIterable, Identifiable {
    case compact, detailed, minimal
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

class SettingsStore: ObservableObject {
    @Published var host: String {
        didSet { UserDefaults.standard.set(host, forKey: "sm_host") }
    }
    @Published var token: String {
        didSet { UserDefaults.standard.set(token, forKey: "sm_token") }
    }
    @Published var glassesFormat: GlassesFormat {
        didSet { UserDefaults.standard.set(glassesFormat.rawValue, forKey: "sm_glassesFormat") }
    }
    @Published var pollingInterval: Double {
        didSet { UserDefaults.standard.set(pollingInterval, forKey: "sm_pollingInterval") }
    }

    init() {
        host = UserDefaults.standard.string(forKey: "sm_host") ?? ""
        token = UserDefaults.standard.string(forKey: "sm_token") ?? ""
        let fmt = UserDefaults.standard.string(forKey: "sm_glassesFormat") ?? GlassesFormat.compact.rawValue
        glassesFormat = GlassesFormat(rawValue: fmt) ?? .compact
        let interval = UserDefaults.standard.double(forKey: "sm_pollingInterval")
        pollingInterval = interval > 0 ? interval : 5.0
    }
}
