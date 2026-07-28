import AppKit
import SwiftUI

/// Renders one device from its `controlsConf`, rather than hardcoding
/// behaviour per model. Speed, Mode and Oscillation get purpose-built
/// controls; any other section with selectable values falls back to a chip
/// row, so an unfamiliar product still gets something usable.
struct DeviceControlView: View {
    let appModel: AppModel
    let device: DreoDevice

    @Environment(\.colorScheme) private var scheme
    @State private var showsPreferences = false

    private var sections: [ControlSection] { device.controlsConf?.control ?? [] }
    private var preferences: [ControlSection] {
        (device.controlsConf?.preference ?? []).filter { $0.cmd != nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.roomy) {
            header

            if !device.isOnline {
                Text("This device is offline. Check it has power and is in range of your WiFi.")
                    .font(Theme.Font.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if sections.isEmpty && preferences.isEmpty {
                Text("No controls published for this model. Power still works.")
                    .font(Theme.Font.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: Theme.Space.roomy) {
                    ForEach(sections) { section in
                        sectionView(for: section)
                    }
                    if !preferences.isEmpty {
                        preferencesSection
                    }
                }
                // Nothing sent to an unreachable device can take effect, so
                // its controls stop accepting input rather than silently
                // dropping commands. The header stays live so an offline
                // device can still be managed and removed.
                .disabled(!device.isOnline)
            }
        }
        .padding(Theme.Metric.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: Theme.Metric.cardRadius, style: .continuous)
                .fill(Theme.surface(scheme))
        )
        .opacity(cardOpacity)
        .animation(.easeOut(duration: 0.18), value: device.isOn)
        .animation(.easeOut(duration: 0.18), value: device.isOnline)
        // Kept out of the card body so a destructive action can't be hit by
        // mistake while reaching for a speed or mode control.
        .contextMenu {
            Button("Remove \(device.deviceName)…", role: .destructive, action: confirmRemoval)
        }
    }

    /// Runs as a real modal alert rather than a SwiftUI confirmation dialog.
    /// The menu bar popover closes as soon as it loses focus, and a dialog
    /// presented from inside it goes with it, so the confirmation vanished
    /// the moment it was clicked. A window-level alert outlives the popover
    /// and stays put until one of its buttons is chosen.
    private func confirmRemoval() {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Remove \(device.deviceName)?"
        alert.informativeText = "This unlinks the fan from your Dreo account everywhere, not just on "
            + "this Mac. To use it again you would have to pair it from scratch."
        alert.addButton(withTitle: "Remove Device")
        alert.addButton(withTitle: "Cancel")
        alert.buttons[0].hasDestructiveAction = true
        // Return picks Cancel, so leaning on the keyboard cannot delete a
        // device by accident.
        alert.buttons[0].keyEquivalent = ""
        alert.buttons[1].keyEquivalent = "\r"

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        Task { await appModel.removeDevice(device) }
    }

    // MARK: - Header

    private var cardOpacity: Double {
        if !device.isOnline { return 0.55 }
        return device.isOn ? 1 : 0.72
    }

    private var iconTint: Color {
        guard device.isOnline else { return .secondary }
        return device.isOn ? Theme.accent : .secondary
    }

    private var header: some View {
        HStack(spacing: Theme.Space.snug) {
            ZStack {
                Circle()
                    .fill(iconTint.opacity(0.18))
                    .frame(width: 30, height: 30)
                Image(systemName: device.isOnline ? (device.isOn ? "fan.fill" : "fan") : "fan.slash")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(iconTint)
                    .symbolEffect(.variableColor.iterative, isActive: device.isOn && device.isOnline)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(device.deviceName)
                    .font(Theme.Font.deviceName)
                    .lineLimit(1)
                HStack(spacing: 5) {
                    if device.isOnline {
                        Text(device.model)
                        if let temperature = device.state["temperature"]?.intValue {
                            Text("·")
                            Text("\(temperature)°")
                                .monospacedDigit()
                        }
                    } else {
                        Text("Offline")
                            .foregroundStyle(.secondary)
                        Text("·")
                        Text(device.model)
                    }
                }
                .font(Theme.Font.deviceMeta)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            }

            Spacer(minLength: Theme.Space.tight)

            DeviceOptionsMenu(deviceName: device.deviceName, onRemove: confirmRemoval)

            Toggle("Power", isOn: Binding(
                get: { device.isOn },
                set: { _ in appModel.togglePower(for: device) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func sectionView(for section: ControlSection) -> some View {
        switch section.type {
        case "Speed":
            speedControl(for: section)
        case "Oscillation":
            oscillationControl(for: section)
        default:
            chipSection(for: section)
        }
    }

    @ViewBuilder
    private func speedControl(for section: ControlSection) -> some View {
        if let items = section.items, items.count >= 2,
           let low = items.map(\.value).compactMap(\.intValue).min(),
           let high = items.map(\.value).compactMap(\.intValue).max(),
           low < high, let cmd = items.first?.cmd {
            let current = min(max(device.state[cmd]?.intValue ?? low, low), high)
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                SectionLabel(title: sectionTitle(section), trailing: "\(current)")
                StepSlider(range: low...high, value: current) { step in
                    appModel.setValue(.int(step), forKey: cmd, on: device)
                }
            }
        }
    }

    @ViewBuilder
    private func oscillationControl(for section: ControlSection) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            HStack(spacing: Theme.Space.tight) {
                SectionLabel(title: sectionTitle(section))
                if let cmd = section.cmd {
                    Toggle("", isOn: Binding(
                        get: { device.state[cmd]?.boolValue ?? false },
                        set: { appModel.setValue(.bool($0), forKey: cmd, on: device) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                }
            }
            if let items = section.items, !items.isEmpty {
                chipRow(items: items)
            }
        }
    }

    @ViewBuilder
    private func chipSection(for section: ControlSection) -> some View {
        if let items = section.items, !items.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                SectionLabel(title: sectionTitle(section))
                chipRow(items: items)
            }
        }
    }

    private func chipRow(items: [ControlItem]) -> some View {
        let selected = items.first { device.state[$0.cmd] == $0.value }?.id
        return SegmentedChips(
            items: items,
            selection: selected,
            label: { $0.text.dreoTitleCased },
            action: { appModel.setValue($0.value, forKey: $0.cmd, on: device) }
        )
    }

    // MARK: - Preferences

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            Button {
                showsPreferences.toggle()
            } label: {
                HStack(spacing: 4) {
                    Text(showsPreferences ? "Fewer options" : "More options")
                        .font(Theme.Font.sectionLabel)
                        .tracking(0.7)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .rotationEffect(.degrees(showsPreferences ? 0 : -90))
                    Spacer(minLength: 0)
                }
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showsPreferences {
                VStack(spacing: Theme.Space.snug) {
                    ForEach(preferences) { preference in
                        ToggleRow(
                            title: sectionTitle(preference),
                            isOn: Binding(
                                get: { isPreferenceOn(preference) },
                                set: { setPreference(preference, to: $0) }
                            )
                        )
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.snappy(duration: 0.2), value: showsPreferences)
    }

    /// Some preferences read inverted (`muteon` is true when panel sound is
    /// off) and some use ints instead of booleans, so both are normalised
    /// to what the label actually claims.
    private func isPreferenceOn(_ section: ControlSection) -> Bool {
        guard let cmd = section.cmd, let raw = device.state[cmd] else { return false }
        let enabled = section.trueValue.map { raw == $0 } ?? (raw.boolValue ?? false)
        return (section.reverse ?? false) ? !enabled : enabled
    }

    private func setPreference(_ section: ControlSection, to newValue: Bool) {
        guard let cmd = section.cmd else { return }
        let target = (section.reverse ?? false) ? !newValue : newValue
        let value: DreoValue
        if let onValue = section.trueValue, let offValue = section.falseValue {
            value = target ? onValue : offValue
        } else {
            value = .bool(target)
        }
        appModel.setValue(value, forKey: cmd, on: device)
    }

    private func sectionTitle(_ section: ControlSection) -> String {
        (section.title ?? section.type).dreoTitleCased
    }
}

extension String {
    /// Schemas from the server carry raw localisation keys such as
    /// `device_control_mode_sleep`, while the bundled templates already hold
    /// English. Keys are looked up in the vendor's own string table first, so
    /// labels read the way the Dreo app words them, and anything unknown falls
    /// back to tidying the key itself.
    var dreoTitleCased: String {
        if let label = DeviceLabels.text(forKey: self) { return label }
        guard contains("_") else { return self }
        var words = split(separator: "_").map(String.init)
            .filter { !["device", "control", "fans", "base"].contains($0.lowercased()) }
        if words.count > 1, words.first?.lowercased() == "mode" {
            words.removeFirst()
        }
        if words.isEmpty { words = [self] }
        return words.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }
}

/// Per-device actions behind a visible button. A right-click only menu is
/// undiscoverable: nothing on screen advertises that it exists.
struct DeviceOptionsMenu: View {
    let deviceName: String
    let onRemove: () -> Void

    var body: some View {
        Menu {
            Button("Remove Device…", role: .destructive, action: onRemove)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 20)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Device options")
        .accessibilityLabel("Options for \(deviceName)")
    }
}
