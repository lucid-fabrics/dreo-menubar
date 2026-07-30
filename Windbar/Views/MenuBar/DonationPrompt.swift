#if WINDBAR_DONATIONS
import SwiftUI

/// The donation ask, direct-download build only. Absent from the App Store build.
///
/// Deliberately quiet: it sits inside the popover the user already opened rather
/// than stealing focus with a window, it never blocks a control, and one click
/// closes it. The gating in `DonationCoordinator` means most people see this once
/// after four months of real use, if ever.
struct DonationPrompt: View {
    let coordinator: DonationCoordinator

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            HStack(spacing: Theme.Space.tight) {
                Text("Windbar is free")
                    .font(Theme.Font.deviceName)
                Spacer(minLength: 0)
                Button {
                    coordinator.dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
            }

            Text("If it has saved you a few trips across the room, you can chip in.")
                .font(Theme.Font.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Theme.Space.tight) {
                ForEach(Donations.links, id: \.label) { link in
                    Button(link.label) {
                        if let url = URL(string: link.url) { openURL(url) }
                        coordinator.dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                Button("No thanks") { coordinator.optOut() }
                    .buttonStyle(.plain)
                    .font(Theme.Font.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, Theme.Space.hairline)
        }
        .padding(Theme.Metric.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Metric.cardRadius, style: .continuous)
                .fill(Theme.surface(colorScheme))
        )
    }
}
#endif
