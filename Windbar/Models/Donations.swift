#if WINDBAR_DONATIONS
import Foundation
import Observation

/// Donation prompt for the direct-download build only.
///
/// This whole file compiles to nothing in the App Store build. `WINDBAR_DONATIONS`
/// is set only by `fastlane mac release_dmg`, never by `release`. That is not
/// tidiness: App Review guideline 3.1.1 forbids pointing users at a payment
/// mechanism outside the App Store, so the shipped App Store binary must not
/// contain this code at all, not merely hide it behind a flag at runtime.
///
/// THE TIMING RULES, AND WHY
///
/// Asking too early is what makes these things feel like a shakedown. The ask is
/// only earned once the app has demonstrably saved someone time, so the gate is
/// deliberately conservative on every axis:
///
/// - not before 14 days of having the app, so a trial-and-delete user never sees it
/// - not before 50 real toggles, so a curious poke does not count
/// - not before 7 separate days of use, so 50 toggles in one afternoon does not count
/// - never twice within 120 days
/// - three times in the app's whole life, then silent forever
/// - one click on "No thanks" and it never returns
///
/// Together those mean the median user sees this at most once or twice, ever, and
/// only after the app has been genuinely useful to them.
enum Donations {
    /// Live Stripe Payment Links. Checkout shows "Lucid Fabrics", which matches the
    /// GitHub org this is published under, so the name is one a donor recognises.
    /// The links are public by design; they are the whole point of shipping them.
    static let links: [(label: String, url: String)] = [
        ("$5", "https://buy.stripe.com/dRmfZg2K7aTOcD0dMMgYU00"),
        ("$10", "https://buy.stripe.com/7sY7sK1G36Dy46u6kkgYU01"),
        ("$20", "https://buy.stripe.com/cNi00i3Ob7HCbyWdMMgYU02")
    ]

    static var isConfigured: Bool { links.allSatisfy { !$0.url.isEmpty } }

    static let minimumDaysInstalled = 14
    static let minimumToggles = 50
    static let minimumActiveDays = 7
    static let cooldownDays = 120
    static let maximumLifetimePrompts = 3
}

/// Counters behind the prompt. Deliberately dumb and local: no identifiers, no
/// network, nothing that leaves the Mac. See docs/PRIVACY.md.
struct DonationState: Codable, Equatable, Sendable {
    var firstLaunch: Date?
    var toggleCount: Int = 0
    /// Days the app was actually used, as yyyy-MM-dd strings. A set, so ten
    /// toggles in one evening count once.
    var activeDays: Set<String> = []
    var lastPrompt: Date?
    var promptCount: Int = 0
    var optedOut: Bool = false

    static let `default` = DonationState()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    mutating func recordUse(now: Date = Date()) {
        if firstLaunch == nil { firstLaunch = now }
        toggleCount += 1
        activeDays.insert(Self.dayFormatter.string(from: now))
    }

    mutating func recordPrompt(now: Date = Date()) {
        lastPrompt = now
        promptCount += 1
    }

    /// Whether the user has *earned* the ask. Deliberately says nothing about
    /// whether links exist to show them: that is a deployment concern, checked
    /// separately by `canPrompt`, so this stays pure and testable.
    func shouldPrompt(now: Date = Date()) -> Bool {
        guard !optedOut else { return false }
        guard promptCount < Donations.maximumLifetimePrompts else { return false }
        guard let first = firstLaunch else { return false }

        let days = Calendar.current.dateComponents([.day], from: first, to: now).day ?? 0
        guard days >= Donations.minimumDaysInstalled else { return false }
        guard toggleCount >= Donations.minimumToggles else { return false }
        guard activeDays.count >= Donations.minimumActiveDays else { return false }

        if let last = lastPrompt {
            let since = Calendar.current.dateComponents([.day], from: last, to: now).day ?? 0
            guard since >= Donations.cooldownDays else { return false }
        }
        return true
    }

    /// What the UI actually asks. Earned, and there is somewhere to send them.
    func canPrompt(now: Date = Date()) -> Bool {
        Donations.isConfigured && shouldPrompt(now: now)
    }
}

/// Owns the counters and decides, once per popover, whether to show the ask.
///
/// Storage is UserDefaults rather than `AppSettings` so that nothing about
/// donations exists in the types the App Store build compiles.
@MainActor
@Observable
final class DonationCoordinator {
    private(set) var isShowing = false

    @ObservationIgnored private var state: DonationState
    @ObservationIgnored private let defaults: UserDefaults
    private static let storageKey = "donationState"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        state = defaults.data(forKey: Self.storageKey)
            .flatMap { try? JSONDecoder().decode(DonationState.self, from: $0) } ?? DonationState()
        // Clock starts at install, not at first toggle. Someone who leaves the app
        // running untouched for three weeks has still had it for three weeks.
        if state.firstLaunch == nil {
            state.firstLaunch = Date()
            save()
        }
    }

    func recordToggle() {
        state.recordUse()
        save()
    }

    /// Call when the popover opens.
    ///
    /// Records the prompt at the moment it is shown rather than when it is acted
    /// on, so closing and reopening the popover cannot produce a second ask. With
    /// the 120 day cooldown that means at most one visible ask per four months.
    func popoverDidOpen() {
        guard !isShowing, state.canPrompt() else { return }
        state.recordPrompt()
        save()
        isShowing = true
    }

    /// Dismissed for now. The cooldown decides when, or whether, it returns.
    func dismiss() { isShowing = false }

    /// "No thanks", which has to mean never again.
    func optOut() {
        state.optedOut = true
        save()
        isShowing = false
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(state), forKey: Self.storageKey)
    }
}
#endif
