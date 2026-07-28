import SwiftUI

/// Design tokens for the whole app. Everything reads through here so light
/// and dark stay in step and spacing keeps a single rhythm.
///
/// Surfaces are built from translucent neutrals layered over the menu bar
/// material rather than opaque greys, so the popover keeps its vibrancy in
/// both appearances. Accent colour is reserved for state that is genuinely
/// active; nothing decorative uses it.
enum Theme {
    enum Metric {
        static let popoverWidth: CGFloat = 320
        static let cardRadius: CGFloat = 11
        static let controlRadius: CGFloat = 8
        static let cardPadding: CGFloat = 12
        static let gutter: CGFloat = 12
    }

    enum Space {
        static let hairline: CGFloat = 2
        static let tight: CGFloat = 6
        static let snug: CGFloat = 10
        static let roomy: CGFloat = 14
        static let loose: CGFloat = 20
    }

    /// Card and control fills. Never a coloured border on a rounded
    /// container, the surface itself carries the hierarchy.
    static func surface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.055) : Color.black.opacity(0.038)
    }

    static func surfaceRaised(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.09) : Color.black.opacity(0.065)
    }

    static func hairline(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.07) : Color.black.opacity(0.07)
    }

    enum Font {
        static let deviceName = SwiftUI.Font.system(size: 13, weight: .semibold)
        static let deviceMeta = SwiftUI.Font.system(size: 10, weight: .medium)
        static let sectionLabel = SwiftUI.Font.system(size: 9.5, weight: .semibold)
        static let chip = SwiftUI.Font.system(size: 11, weight: .medium)
        static let row = SwiftUI.Font.system(size: 12.5, weight: .regular)
        static let body = SwiftUI.Font.system(size: 12)
        static let caption = SwiftUI.Font.system(size: 11)
        static let readout = SwiftUI.Font.system(size: 13, weight: .semibold, design: .rounded)
    }
}

/// Uppercase micro-label introducing a control group, with an optional
/// trailing readout such as the current speed.
struct SectionLabel: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.tight) {
            Text(title.uppercased())
                .font(Theme.Font.sectionLabel)
                .tracking(0.7)
                .foregroundStyle(.secondary)
            Spacer(minLength: Theme.Space.tight)
            if let trailing {
                Text(trailing)
                    .font(Theme.Font.readout)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
            }
        }
    }
}
