import SwiftUI

struct GlassesPreviewView: View {
    @ObservedObject var vm: SnapmakerViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                glassesScreen
                formatPicker
                if let state = vm.machineState {
                    rawJsonBox(state)
                }
            }
            .padding()
        }
    }

    // MARK: - Glasses mockup

    private var glassesScreen: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black)
                .aspectRatio(16 / 5, contentMode: .fit)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 4) {
                ForEach(glassesLines, id: \.self) { line in
                    Text(line)
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                }
            }
            .padding(12)
        }
        .shadow(radius: 8)
    }

    private var glassesLines: [String] {
        guard let state = vm.machineState else {
            return ["No data — connect to Snapmaker"]
        }
        let formatted = vm.formatForGlasses(state, format: vm.settingsStore.glassesFormat)
        return formatted.components(separatedBy: "\n")
    }

    // MARK: - Format picker

    private var formatPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Display Format")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            Picker("Format", selection: $vm.settingsStore.glassesFormat) {
                ForEach(GlassesFormat.allCases) { fmt in
                    Text(fmt.displayName).tag(fmt)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Raw JSON

    private func rawJsonBox(_ state: MachineState) -> some View {
        GroupBox("Raw JSON (TCP :8089)") {
            ScrollView(.horizontal, showsIndicators: false) {
                Text(buildJsonPreview(state))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func buildJsonPreview(_ state: MachineState) -> String {
        var dict: [String: Any] = [
            "type": "status",
            "machineStatus": state.status.rawValue,
            "fileName": state.fileName,
            "completion": String(format: "%.1f", state.completionPct),
            "timeLeft": state.progress?.printTimeLeft ?? 0,
            "elapsed": state.progress?.printTime ?? 0
        ]
        if let ext = state.extruder { dict["nozzleTemp"] = Int(ext.current) }
        if let bed = state.heatedBed { dict["bedTemp"] = Int(bed.current) }

        if let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{}"
    }
}
