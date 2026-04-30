import SwiftUI

struct DashboardView: View {
    @ObservedObject var vm: SnapmakerViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                connectionCard
                if vm.waitingForMachineApproval {
                    approvalBanner
                }
                if let state = vm.machineState {
                    statusCard(state)
                    if state.isActive {
                        progressCard(state)
                    }
                    if state.extruder != nil || state.heatedBed != nil {
                        temperatureCard(state)
                    }
                    positionCard(state)
                } else if vm.connectionState.isConnected {
                    ProgressView("Loading machine state…")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .padding()
        }
    }

    // MARK: - Connection Card

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: connectionIcon)
                    .font(.title2)
                    .foregroundColor(connectionColor)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(connectionTitle)
                        .font(.headline)
                    Text(vm.settingsStore.host.isEmpty ? "No IP configured — open Settings" : vm.settingsStore.host)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                connectButton
            }
            if let err = vm.lastError {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 2)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private var approvalBanner: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text("Check your Snapmaker screen and tap **Allow** to authorize this connection.")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color.orange.opacity(0.12))
        .cornerRadius(12)
    }

    private var connectButton: some View {
        Button {
            if vm.connectionState.isConnected {
                vm.disconnect()
            } else {
                Task { await vm.connect() }
            }
        } label: {
            Text(vm.connectionState.isConnected ? "Disconnect" : "Connect")
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(vm.connectionState.isConnected
                    ? Color.red.opacity(0.12)
                    : Color.blue.opacity(0.12))
                .foregroundColor(vm.connectionState.isConnected ? .red : .blue)
                .cornerRadius(8)
        }
        .disabled(vm.waitingForMachineApproval)
    }

    private var connectionIcon: String {
        switch vm.connectionState {
        case .disconnected: return "wifi.slash"
        case .connecting:   return "wifi"
        case .connected:    return "wifi"
        case .error:        return "exclamationmark.wifi"
        }
    }

    private var connectionColor: Color {
        switch vm.connectionState {
        case .disconnected: return .secondary
        case .connecting:   return .orange
        case .connected:    return .green
        case .error:        return .red
        }
    }

    private var connectionTitle: String {
        switch vm.connectionState {
        case .disconnected: return "Disconnected"
        case .connecting:   return "Connecting…"
        case .connected:    return "Connected"
        case .error:        return "Connection Error"
        }
    }

    // MARK: - Status Card

    private func statusCard(_ state: MachineState) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Status")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(state.status.displayName)
                    .font(.title2.bold())
                    .foregroundColor(statusColor(state.status))
                if !state.fileName.isEmpty {
                    Text(state.shortFileName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            Image(systemName: statusIcon(state.status))
                .font(.system(size: 44))
                .foregroundColor(statusColor(state.status).opacity(0.8))
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Progress Card

    private func progressCard(_ state: MachineState) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 24) {
                // Progress ring
                ZStack {
                    Circle()
                        .stroke(Color(.systemFill), lineWidth: 12)
                    Circle()
                        .trim(from: 0, to: CGFloat(state.completionPct / 100))
                        .stroke(
                            statusColor(state.status),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.6), value: state.completionPct)
                    VStack(spacing: 1) {
                        Text("\(Int(state.completionPct))%")
                            .font(.title2.bold())
                            .monospacedDigit()
                        Text("done")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 100, height: 100)

                VStack(alignment: .leading, spacing: 10) {
                    infoRow(icon: "clock",     label: "Elapsed",   value: state.elapsedFormatted)
                    infoRow(icon: "hourglass", label: "Remaining", value: state.timeLeftFormatted)
                    if let p = state.progress, p.filamentUsed > 0 {
                        infoRow(icon: "cable.connector",
                                label: "Filament",
                                value: String(format: "%.1f m", p.filamentUsed / 1000))
                    }
                }
            }
            .padding()
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .imageScale(.small)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline.bold())
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Temperature Card

    private func temperatureCard(_ state: MachineState) -> some View {
        HStack(spacing: 0) {
            if let ext = state.extruder {
                tempCell(label: "Nozzle", reading: ext, icon: "flame.fill", color: .orange)
            }
            if state.extruder != nil && state.heatedBed != nil {
                Divider().padding(.vertical, 12)
            }
            if let bed = state.heatedBed {
                tempCell(label: "Bed", reading: bed, icon: "square.fill", color: .red)
            }
        }
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func tempCell(label: String, reading: TemperatureReading, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(reading.current > 40 ? color : .secondary)
                .imageScale(.small)
            Text("\(Int(reading.current))°C")
                .font(.title3.bold())
                .monospacedDigit()
            if reading.target > 0 {
                Text("/ \(Int(reading.target))°")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Position Card

    private func positionCard(_ state: MachineState) -> some View {
        HStack(spacing: 0) {
            axisCell("X", value: state.x, color: .red)
            Divider()
            axisCell("Y", value: state.y, color: .green)
            Divider()
            axisCell("Z", value: state.z, color: .blue)
        }
        .frame(height: 72)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func axisCell(_ axis: String, value: Double, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(axis)
                .font(.caption2.bold())
                .foregroundColor(color)
            Text(String(format: "%.1f", value))
                .font(.subheadline.bold())
                .monospacedDigit()
            Text("mm")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func statusColor(_ s: MachineStatus) -> Color {
        switch s {
        case .idle:    return .secondary
        case .printing: return .green
        case .paused:  return .orange
        case .error:   return .red
        case .unknown: return .gray
        }
    }

    private func statusIcon(_ s: MachineStatus) -> String {
        switch s {
        case .idle:    return "printer"
        case .printing: return "printer.fill"
        case .paused:  return "pause.circle.fill"
        case .error:   return "exclamationmark.triangle.fill"
        case .unknown: return "questionmark.circle"
        }
    }
}
