import SwiftUI

/// A pill-shaped choice button used for Mode and Oscillation-angle rows.
/// Selection is shown with a filled background, never a colored border.
struct CapsuleChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .background(
            Capsule().fill(isSelected ? Color.accentColor : Color.primary.opacity(0.06))
        )
        .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.85))
        .animation(.easeOut(duration: 0.12), value: isSelected)
    }
}

/// Small uppercase-weight caption used to introduce a control group, with
/// an optional trailing value (e.g. the current speed number).
struct SectionHeader: View {
    let icon: String
    let title: String
    var trailing: String?

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(title)
                .font(.system(size: 11, weight: .semibold))
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
        }
        .foregroundStyle(.secondary)
    }
}

/// A full-width row button with a hover highlight, used for the footer
/// (Preferences/Quit) instead of stock bordered `Button`s.
struct HoverRow: View {
    let icon: String
    let title: String
    var isLoading = false
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                        .frame(width: 14)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 14)
                }
                Text(title)
                    .font(.system(size: 12.5))
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovering ? Color.primary.opacity(0.08) : Color.clear)
        )
        .onHover { isHovering = $0 }
    }
}

/// A muted, filled (never bordered) chip for surfacing a transient error.
struct InlineErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
            Text(message)
                .font(.system(size: 11))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.red)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.12)))
    }
}
