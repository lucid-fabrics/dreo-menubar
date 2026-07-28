import SwiftUI

/// A row of mutually exclusive options with the selection sliding between
/// them. Selection reads as a filled pill, never a coloured border.
struct SegmentedChips<Item: Identifiable & Equatable>: View {
    let items: [Item]
    let selection: Item.ID?
    let label: (Item) -> String
    let action: (Item) -> Void

    @Environment(\.colorScheme) private var scheme
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 3) {
            ForEach(items) { item in
                let isSelected = item.id == selection
                Button {
                    action(item)
                } label: {
                    Text(label(item))
                        .font(Theme.Font.chip)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.75))
                        .background {
                            if isSelected {
                                Capsule(style: .continuous)
                                    .fill(Color.accentColor)
                                    .matchedGeometryEffect(id: "selection", in: pill)
                            }
                        }
                        .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule(style: .continuous).fill(Theme.surface(scheme)))
        .animation(.snappy(duration: 0.22), value: selection)
    }
}

/// Speed control drawn as a discrete track: each step is a tick, the filled
/// portion shows the current level, and the whole bar is draggable.
struct StepSlider: View {
    let range: ClosedRange<Int>
    let value: Int
    let onChange: (Int) -> Void

    @Environment(\.colorScheme) private var scheme

    private var steps: Int { max(range.upperBound - range.lowerBound, 1) }
    private var progress: Double { Double(value - range.lowerBound) / Double(steps) }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surfaceRaised(scheme))

                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: max(10, width * progress))

                HStack(spacing: 0) {
                    ForEach(range.lowerBound...range.upperBound, id: \.self) { step in
                        if step > range.lowerBound { Spacer(minLength: 0) }
                        Circle()
                            .fill(Color.white.opacity(step <= value ? 0.5 : 0.18))
                            .frame(width: 2, height: 2)
                    }
                }
                .padding(.horizontal, 5)
            }
            .frame(height: 10)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        guard width > 0 else { return }
                        let ratio = min(max(drag.location.x / width, 0), 1)
                        let step = range.lowerBound + Int((ratio * Double(steps)).rounded())
                        if step != value { onChange(step) }
                    }
            )
        }
        .frame(height: 10)
        .animation(.snappy(duration: 0.18), value: value)
    }
}

/// Labelled switch used for device preferences such as Child Lock.
struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: Theme.Space.tight) {
            Text(title)
                .font(Theme.Font.body)
            Spacer(minLength: Theme.Space.tight)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
        }
    }
}

/// Full-width action row with a hover highlight, used for the popover footer.
struct HoverRow: View {
    let icon: String
    let title: String
    var isLoading = false
    let action: () -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.snug) {
                Group {
                    if isLoading {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 11.5, weight: .medium))
                    }
                }
                .frame(width: 15)
                .foregroundStyle(.secondary)

                Text(title)
                    .font(Theme.Font.row)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.Space.snug)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Metric.controlRadius, style: .continuous)
                .fill(isHovering ? Theme.surface(scheme) : .clear)
        )
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
    }
}

/// Muted filled banner for a transient error. Filled, never bordered.
struct InlineErrorBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Space.tight) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
            Text(message)
                .font(Theme.Font.caption)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.red)
        .padding(.horizontal, Theme.Space.snug)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Metric.controlRadius, style: .continuous)
                .fill(Color.red.opacity(0.12))
        )
    }
}

/// Progress dots for a short linear flow. Communicates how much is left,
/// which a spinner alone cannot.
struct StepDots: View {
    let total: Int
    let current: Int

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Color.accentColor : Theme.surfaceRaised(scheme))
                    .frame(width: index == current ? 16 : 6, height: 6)
            }
        }
        .animation(.snappy(duration: 0.25), value: current)
        .accessibilityLabel("Step \(current + 1) of \(total)")
    }
}

/// Centred placeholder for empty, busy and error states.
struct StatusPlaceholder: View {
    var systemImage: String?
    var isBusy = false
    let message: String

    var body: some View {
        VStack(spacing: Theme.Space.snug) {
            if isBusy {
                ProgressView().controlSize(.small)
            } else if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(.tertiary)
            }
            Text(message)
                .font(Theme.Font.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.loose + 8)
        .padding(.horizontal, Theme.Space.roomy)
    }
}
