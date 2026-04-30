import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    @ObservedObject var vm: SnapmakerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                machineSection
                glassesSection
                pollingSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Machine

    private var machineSection: some View {
        Section {
            HStack {
                Text("IP Address")
                Spacer()
                TextField("192.168.1.x", text: $store.host)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numbersAndPunctuation)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }

            if !store.token.isEmpty {
                HStack {
                    Text("Token")
                    Spacer()
                    Text(store.token.prefix(12) + "…")
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                }
            }

            if vm.connectionState.isConnected {
                Button(role: .destructive) {
                    vm.disconnect()
                } label: {
                    Label("Disconnect", systemImage: "wifi.slash")
                }
            } else {
                Button {
                    Task { await vm.connect() }
                    dismiss()
                } label: {
                    Label(store.token.isEmpty ? "Connect & Authorize" : "Reconnect",
                          systemImage: "wifi")
                }
                .disabled(store.host.isEmpty)
            }
        } header: {
            Text("Snapmaker Machine")
        } footer: {
            Text("Enter the local IP address of your Snapmaker U1. On first connect the machine will show an authorization prompt — tap Allow on its screen.")
        }
    }

    // MARK: - Glasses

    private var glassesSection: some View {
        Section("Glasses Display") {
            Picker("Format", selection: $store.glassesFormat) {
                ForEach(GlassesFormat.allCases) { fmt in
                    Text(fmt.displayName).tag(fmt)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Image(systemName: "circle.fill")
                    .foregroundColor(vm.glassesConnected ? .green : .gray)
                    .imageScale(.small)
                Text(vm.glassesConnected
                     ? "\(vm.glassesClientCount) glasses connected  (TCP :8089)"
                     : "No glasses connected  (TCP :8089)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Polling

    private var pollingSection: some View {
        Section {
            HStack {
                Text("Poll interval")
                Spacer()
                Text("\(Int(store.pollingInterval))s")
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            Slider(value: $store.pollingInterval, in: 2...30, step: 1)
        } header: {
            Text("Polling")
        } footer: {
            Text("When printing, status is fetched every \(Int(store.pollingInterval))s. When idle, every \(Int(store.pollingInterval * 3))s.")
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Protocol", value: "Snapmaker HTTP API (:8080)")
            LabeledContent("Glasses TCP port", value: "8089")
            LabeledContent("Version", value: "1.0")
        }
    }
}
