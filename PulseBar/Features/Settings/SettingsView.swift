import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(SystemMonitor.self) private var monitor
    @State private var launchAtLogin = LaunchAtLoginController()
    @AppStorage(SettingsKey.refreshPreset) private var refreshPreset = RefreshPreset.normal.rawValue
    @AppStorage(SettingsKey.appearance) private var appearance = AppAppearance.system.rawValue
    @AppStorage(SettingsKey.dashboardLiquidGlass) private var dashboardLiquidGlass = true
    @AppStorage(SettingsKey.dashboardBackgroundTint) private var dashboardBackgroundTint = DashboardBackgroundTint.black.rawValue
    @AppStorage(SettingsKey.dashboardOpacity) private var dashboardOpacity = DashboardAppearance.defaultOpacityLevel
    @AppStorage(SettingsKey.compactMenuBar) private var compactMenuBar = false
    @AppStorage(SettingsKey.menuBarWidthBehavior) private var menuBarWidthBehavior = MenuBarWidthBehavior.fixed.rawValue
    @AppStorage(SettingsKey.menuBarMetricOrder) private var storedMenuBarOrder = MenuBarMetric.defaultOrderValue
    @State private var menuBarOrder = MenuBarMetric.allCases
    @State private var draggedMenuBarMetric: MenuBarMetric?

    var body: some View {
        TabView {
            Form {
                Toggle("Launch at Login", isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: launchAtLogin.setEnabled
                ))
                if let error = launchAtLogin.errorMessage { Text(error).font(.caption).foregroundStyle(.red) }
                Picker("Refresh Speed", selection: $refreshPreset) {
                    ForEach(RefreshPreset.allCases) { preset in Text("\(preset.title) — \(preset.detail)").tag(preset.rawValue) }
                }
                Section("Appearance") {
                    Picker("App theme", selection: $appearance) {
                        ForEach(AppAppearance.allCases) { option in Text(option.title).tag(option.rawValue) }
                    }
                    Toggle("Enable Liquid Glass effect", isOn: $dashboardLiquidGlass)
                    Picker("Background Tint", selection: $dashboardBackgroundTint) {
                        ForEach(DashboardBackgroundTint.allCases) { tint in
                            Text(tint.title).tag(tint.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(!dashboardLiquidGlass)
                    HStack {
                        Text("Opacity")
                        Slider(value: $dashboardOpacity, in: 1...10, step: 1)
                            .accessibilityLabel("Dashboard opacity")
                        Text(dashboardOpacity.formatted(.number.precision(.fractionLength(0))))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .frame(width: 18, alignment: .trailing)
                    }
                    .disabled(!dashboardLiquidGlass)
                    Label("For Dark appearance, Black tint and opacity 7 are recommended.", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("For visible transparency, set System Settings → Appearance → Liquid Glass to Clear. The macOS Tinted setting makes popovers opaque on dark backgrounds.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("Liquid Glass creates a dynamic, translucent dashboard that adapts to your desktop. Turn it off for a solid black background.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Section("Application") {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Quit PulseBar")
                            Text("Stop monitoring and close the application.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            NSApplication.shared.terminate(nil)
                        } label: {
                            Label("Quit", systemImage: "power")
                        }
                        .accessibilityLabel("Quit PulseBar")
                    }
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("General", systemImage: "gearshape") }

            Form {
                Toggle("Compact labels", isOn: $compactMenuBar)
                Picker("Statistics width", selection: $menuBarWidthBehavior) {
                    ForEach(MenuBarWidthBehavior.allCases) { behavior in
                        Text(behavior.title).tag(behavior.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                Text(menuBarWidthBehavior == MenuBarWidthBehavior.fixed.rawValue
                     ? "Values stay in fixed positions as they update."
                     : "PulseBar expands and contracts to fit live values.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Section("Statistics order") {
                    ForEach(menuBarOrder) { metric in
                        HStack(spacing: 10) {
                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(.tertiary)
                                .frame(width: 16)
                                .contentShape(Rectangle())
                                .onDrag {
                                    draggedMenuBarMetric = metric
                                    return NSItemProvider(object: metric.rawValue as NSString)
                                }
                                .help("Drag to move \(metric.title)")
                                .accessibilityLabel("Reorder \(metric.title)")
                                .accessibilityHint("Drag to change its menu bar position")
                                .accessibilityAction(named: "Move earlier") {
                                    moveMenuBarMetric(metric, by: -1)
                                }
                                .accessibilityAction(named: "Move later") {
                                    moveMenuBarMetric(metric, by: 1)
                                }
                            Label(metric.title, systemImage: metric.symbol)
                            Spacer()
                            SettingsToggle("", key: metric.visibilityKey)
                                .labelsHidden()
                        }
                        .onDrop(
                            of: [UTType.text],
                            delegate: MenuBarMetricDropDelegate(
                                destination: metric,
                                metrics: $menuBarOrder,
                                draggedMetric: $draggedMenuBarMetric,
                                save: saveMenuBarOrder
                            )
                        )
                    }
                    Text("Drag the handles to arrange statistics. At most five enabled values are shown.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Toggle("Temperature", isOn: .constant(false)).disabled(true)
                Toggle("Fan RPM", isOn: .constant(false)).disabled(true)
            }
            .formStyle(.grouped)
            .tabItem { Label("Menu Bar", systemImage: "menubar.rectangle") }

            Form {
                SettingsToggle("CPU", key: SettingsKey.monitorCPU)
                SettingsToggle("Memory", key: SettingsKey.monitorMemory)
                SettingsToggle("Network", key: SettingsKey.monitorNetwork)
                SettingsToggle("Disk", key: SettingsKey.monitorDisk)
                SettingsToggle("Battery", key: SettingsKey.monitorBattery)
                SettingsToggle("Thermal State", key: SettingsKey.monitorThermal)
                Section("Hardware Sensors") {
                    Toggle("Temperature and fan sensors", isOn: .constant(false)).disabled(true)
                    Text("Unavailable in V1. PulseBar does not use private SMC APIs.").font(.caption).foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("Monitoring", systemImage: "waveform.path.ecg") }

            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 520, height: 390)
        .onAppear {
            launchAtLogin.refresh()
            menuBarOrder = MenuBarMetric.ordered(from: storedMenuBarOrder)
        }
        .onChange(of: refreshPreset) { monitor.restart() }
    }

    private func saveMenuBarOrder(_ metrics: [MenuBarMetric]) {
        storedMenuBarOrder = MenuBarMetric.encode(metrics)
    }

    private func moveMenuBarMetric(_ metric: MenuBarMetric, by offset: Int) {
        guard let sourceIndex = menuBarOrder.firstIndex(of: metric) else { return }
        let destinationIndex = sourceIndex + offset
        guard menuBarOrder.indices.contains(destinationIndex) else { return }
        withAnimation(.easeInOut(duration: 0.16)) {
            menuBarOrder.swapAt(sourceIndex, destinationIndex)
        }
        saveMenuBarOrder(menuBarOrder)
    }
}

private struct AboutView: View {
    var body: some View {
        VStack(spacing: 15) {
            Spacer(minLength: 12)

            Image(nsImage: appIcon)
                .resizable()
                .interpolation(.high)
                .frame(width: 88, height: 88)
                .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
                .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text("PulseBar")
                    .font(.title2.bold())
                Text("Live system statistics, right from your macOS menu bar.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 9) {
                Rectangle().fill(.quaternary).frame(width: 54, height: 1)
                Image(systemName: "waveform.path.ecg")
                    .foregroundStyle(.blue)
                Rectangle().fill(.quaternary).frame(width: 54, height: 1)
            }
            .accessibilityHidden(true)

            VStack(spacing: 5) {
                Text("About the creator")
                    .font(.headline)
                Text("Created by Mark Anthony with a focus on practical, reliable, and thoughtfully designed software.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            Spacer(minLength: 8)

            Text(versionText)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var appIcon: NSImage {
        NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "Version \(version) (\(build))"
    }
}

private struct MenuBarMetricDropDelegate: DropDelegate {
    let destination: MenuBarMetric
    @Binding var metrics: [MenuBarMetric]
    @Binding var draggedMetric: MenuBarMetric?
    let save: ([MenuBarMetric]) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedMetric,
              draggedMetric != destination,
              let sourceIndex = metrics.firstIndex(of: draggedMetric),
              let destinationIndex = metrics.firstIndex(of: destination) else { return }

        withAnimation(.easeInOut(duration: 0.16)) {
            let movedMetric = metrics.remove(at: sourceIndex)
            metrics.insert(movedMetric, at: destinationIndex)
        }
        save(metrics)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedMetric = nil
        save(metrics)
        return true
    }
}

private struct SettingsToggle: View {
    let title: String
    @AppStorage private var value: Bool

    init(_ title: String, key: String) {
        self.title = title
        _value = AppStorage(wrappedValue: true, key)
    }

    var body: some View { Toggle(title, isOn: $value) }
}
