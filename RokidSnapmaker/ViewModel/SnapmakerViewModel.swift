import Foundation
import Combine

enum ConnectionState {
    case disconnected, connecting, connected, error(String)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var description: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting…"
        case .connected: return "Connected"
        case .error(let msg): return msg
        }
    }
}

@MainActor
class SnapmakerViewModel: ObservableObject {
    @Published var connectionState: ConnectionState = .disconnected
    @Published var machineState: MachineState?
    @Published var lastError: String?
    @Published var glassesClientCount: Int = 0
    @Published var waitingForMachineApproval = false

    var glassesConnected: Bool { glassesClientCount > 0 }

    let settingsStore: SettingsStore
    let glassesServer = GlassesServer()
    private let client = SnapmakerClient()
    private var pollTimer: Timer?
    private var prevStatus: MachineStatus?
    private var cancellables = Set<AnyCancellable>()

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore

        glassesServer.$clientCount
            .receive(on: DispatchQueue.main)
            .assign(to: &$glassesClientCount)

        glassesServer.start()

        // Auto-resume if we already have a token stored
        if !settingsStore.host.isEmpty && !settingsStore.token.isEmpty {
            Task { await startPolling() }
        }
    }

    // MARK: - Connection

    func connect() async {
        guard !settingsStore.host.isEmpty else {
            lastError = "Enter the Snapmaker IP address in Settings first."
            return
        }
        connectionState = .connecting
        waitingForMachineApproval = true
        lastError = nil
        do {
            let token = try await client.connect(host: settingsStore.host)
            settingsStore.token = token
            waitingForMachineApproval = false
            await startPolling()
        } catch {
            waitingForMachineApproval = false
            connectionState = .error(error.localizedDescription)
            lastError = error.localizedDescription
        }
    }

    func disconnect() {
        stopPolling()
        machineState = nil
        prevStatus = nil
        connectionState = .disconnected
        lastError = nil
    }

    func refreshNow() async {
        await poll()
    }

    // MARK: - Polling

    private func startPolling() async {
        connectionState = .connected
        await poll()
        scheduleNextPoll()
    }

    private func scheduleNextPoll() {
        stopPolling()
        // Poll faster when printing, slower when idle
        let interval = (machineState?.status == .printing)
            ? settingsStore.pollingInterval
            : settingsStore.pollingInterval * 3
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.poll()
                self?.scheduleNextPoll()
            }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func poll() async {
        guard !settingsStore.host.isEmpty, !settingsStore.token.isEmpty else { return }
        do {
            let state = try await client.getStatus(host: settingsStore.host, token: settingsStore.token)
            checkForAlerts(new: state)
            machineState = state
            broadcast(state)
            if case .error = connectionState { connectionState = .connected }
        } catch {
            if case .connected = connectionState {
                connectionState = .error(error.localizedDescription)
            }
        }
    }

    // MARK: - Alerts

    private func checkForAlerts(new: MachineState) {
        defer { prevStatus = new.status }
        guard let prev = prevStatus else { return }
        switch (prev, new.status) {
        case (.printing, .idle):
            glassesServer.broadcastAlert("✅ Print complete: \(new.shortFileName)")
        case (_, .error) where prev != .error:
            glassesServer.broadcastAlert("⚠️ Printer error!")
        case (.printing, .paused):
            glassesServer.broadcastAlert("⏸ Print paused")
        case (.paused, .printing):
            glassesServer.broadcastAlert("▶ Print resumed")
        default: break
        }
    }

    // MARK: - Glasses broadcast

    private func broadcast(_ state: MachineState) {
        glassesServer.broadcastStatus(state)
        let text = formatForGlasses(state, format: settingsStore.glassesFormat)
        glassesServer.broadcastFormatted(text)
    }

    func formatForGlasses(_ state: MachineState, format: GlassesFormat) -> String {
        let pct  = Int(state.completionPct)
        let left = state.timeLeftFormatted
        let nozzle = state.extruder.map   { "\(Int($0.current))°" } ?? "--"
        let bed    = state.heatedBed.map  { "\(Int($0.current))°" } ?? "--"
        let name   = state.shortFileName

        switch state.status {
        case .printing, .paused:
            let pauseTag = state.status == .paused ? " ⏸" : ""
            switch format {
            case .compact:
                return "\(name)  \(pct)%\(pauseTag)  \(left)  N:\(nozzle) B:\(bed)"
            case .minimal:
                return "\(pct)%\(pauseTag)  \(left) left"
            case .detailed:
                return "\(name)\n\(pct)%\(pauseTag)\nNozzle \(nozzle)  Bed \(bed)\n\(left) remaining"
            }
        case .idle:
            return "Snapmaker ready"
        case .error:
            return "⚠️ Printer error"
        case .unknown:
            return "Connecting…"
        }
    }
}
