import SwiftUI

/// Renders a device's controls generically from its `controlsConf`, rather
/// than hardcoding behavior per model. Speed/Mode/Oscillation are the three
/// section types confirmed on the tower fan this app was built against;
/// anything else falls back to a plain row of tappable chips.
struct DeviceControlView: View {
    let appModel: AppModel
    let device: DreoDevice

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if let sections = device.controlsConf?.control, !sections.isEmpty {
                ForEach(sections) { section in
                    sectionView(for: section)
                }
            } else {
                Text("No controls reported for this device yet. Power still works.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(device.isOn ? Color.accentColor.opacity(0.16) : Color.primary.opacity(0.06))
                    .frame(width: 32, height: 32)
                Image(systemName: device.isOn ? "fan.fill" : "fan")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(device.isOn ? Color.accentColor : Color.secondary)
            }
            .animation(.easeOut(duration: 0.15), value: device.isOn)

            VStack(alignment: .leading, spacing: 1) {
                Text(device.deviceName)
                    .font(.system(size: 13, weight: .semibold))
                Text(device.model)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 8)

            Toggle("Power", isOn: Binding(
                get: { device.isOn },
                set: { _ in appModel.togglePower(for: device) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
        }
    }

    @ViewBuilder
    private func sectionView(for section: ControlSection) -> some View {
        switch section.type {
        case "Speed":
            speedSlider(for: section)
        case "Mode":
            VStack(alignment: .leading, spacing: 6) {
                SectionHeader(icon: "list.bullet", title: (section.title ?? section.type).dreoTitleCased)
                chipRow(items: section.items ?? [])
            }
        case "Oscillation":
            oscillationControls(for: section)
        default:
            fallbackChips(for: section)
        }
    }

    @ViewBuilder
    private func speedSlider(for section: ControlSection) -> some View {
        if let items = section.items, items.count >= 2,
           let low = items.first?.value.intValue,
           let high = items.last?.value.intValue,
           let cmd = items.first?.cmd {
            let current = device.state[cmd]?.intValue ?? low
            VStack(alignment: .leading, spacing: 6) {
                SectionHeader(
                    icon: "wind",
                    title: (section.title ?? section.type).dreoTitleCased,
                    trailing: "\(current)"
                )
                Slider(
                    value: Binding(
                        get: { Double(current) },
                        set: { appModel.setValue(.int(Int($0)), forKey: cmd, on: device) }
                    ),
                    in: Double(low)...Double(high),
                    step: 1
                )
            }
        }
    }

    @ViewBuilder
    private func oscillationControls(for section: ControlSection) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                SectionHeader(icon: "arrow.left.and.right", title: (section.title ?? section.type).dreoTitleCased)
                if let cmd = section.cmd {
                    Spacer()
                    Toggle("Oscillation", isOn: Binding(
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
    private func chipRow(items: [ControlItem]) -> some View {
        if !items.isEmpty {
            let selectedId = items.first(where: { device.state[$0.cmd] == $0.value })?.id ?? items[0].id
            HStack(spacing: 6) {
                ForEach(items) { item in
                    CapsuleChip(
                        title: item.text.dreoTitleCased,
                        isSelected: item.id == selectedId,
                        action: { appModel.setValue(item.value, forKey: item.cmd, on: device) }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func fallbackChips(for section: ControlSection) -> some View {
        if let items = section.items, !items.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                SectionHeader(icon: "slider.horizontal.3", title: (section.title ?? section.type).dreoTitleCased)
                chipRow(items: items)
            }
        }
    }
}

private extension String {
    /// Dreo's `title`/`text` fields are raw localization keys like
    /// `device_control_mode_sleep`. We don't have their string table, so
    /// this is a light heuristic to make them readable instead of raw.
    var dreoTitleCased: String {
        var words = split(separator: "_").map(String.init)
            .filter { !["device", "control", "fans"].contains($0.lowercased()) }
        if words.count > 1, words.first?.lowercased() == "mode" {
            words.removeFirst()
        }
        if words.isEmpty { words = [self] }
        return words.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }
}
