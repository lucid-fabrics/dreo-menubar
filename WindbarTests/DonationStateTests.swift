#if WINDBAR_DONATIONS
import XCTest
@testable import Windbar

/// The donation gate decides whether the app feels respectful or grabby, and every
/// bound is a judgement call that is easy to break later by "just lowering it a
/// bit". These tests pin each one.
final class DonationStateTests: XCTestCase {

    private let day = 86_400.0

    /// Fully-earned state: long enough installed, used enough, across enough days.
    private func earned(now: Date) -> DonationState {
        var state = DonationState()
        state.firstLaunch = now.addingTimeInterval(-30 * day)
        for offset in 0..<10 {
            for _ in 0..<6 {
                state.recordUse(now: now.addingTimeInterval(-Double(offset) * day))
            }
        }
        return state
    }

    func test_freshInstall_neverPrompts() {
        var state = DonationState()
        state.recordUse()
        XCTAssertFalse(state.shouldPrompt(), "a brand new user must never be asked")
    }

    func test_heavyUseButTooRecent_doesNotPrompt() {
        let now = Date()
        var state = DonationState()
        state.firstLaunch = now.addingTimeInterval(-3 * day)
        for offset in 0..<3 {
            for _ in 0..<40 { state.recordUse(now: now.addingTimeInterval(-Double(offset) * day)) }
        }
        XCTAssertGreaterThanOrEqual(state.toggleCount, Donations.minimumToggles)
        XCTAssertFalse(state.shouldPrompt(now: now),
                       "120 toggles in 3 days is enthusiasm, not an earned ask")
    }

    func test_installedLongEnoughButBarelyUsed_doesNotPrompt() {
        let now = Date()
        var state = DonationState()
        state.firstLaunch = now.addingTimeInterval(-200 * day)
        state.recordUse(now: now)
        XCTAssertFalse(state.shouldPrompt(now: now), "age alone must not earn the ask")
    }

    /// The case that motivates tracking distinct days at all.
    func test_manyTogglesOnOneDay_doesNotPrompt() {
        let now = Date()
        var state = DonationState()
        state.firstLaunch = now.addingTimeInterval(-60 * day)
        for _ in 0..<500 { state.recordUse(now: now) }
        XCTAssertEqual(state.activeDays.count, 1)
        XCTAssertFalse(state.shouldPrompt(now: now),
                       "500 toggles in one sitting is one day of use, not seven")
    }

    func test_earnedUsage_prompts() {
        let now = Date()
        XCTAssertTrue(earned(now: now).shouldPrompt(now: now))
    }

    func test_withinCooldown_doesNotPromptAgain() {
        let now = Date()
        var state = earned(now: now)
        state.recordPrompt(now: now.addingTimeInterval(-10 * day))
        XCTAssertFalse(state.shouldPrompt(now: now), "10 days after asking is far too soon")
    }

    func test_afterCooldown_promptsAgain() {
        let now = Date()
        var state = earned(now: now)
        state.recordPrompt(now: now.addingTimeInterval(-Double(Donations.cooldownDays + 1) * day))
        XCTAssertTrue(state.shouldPrompt(now: now))
    }

    func test_lifetimeCap_isHonoured() {
        let now = Date()
        var state = earned(now: now)
        for index in 0..<Donations.maximumLifetimePrompts {
            state.recordPrompt(now: now.addingTimeInterval(-Double(500 - index * 130) * day))
        }
        XCTAssertEqual(state.promptCount, Donations.maximumLifetimePrompts)
        XCTAssertFalse(state.shouldPrompt(now: now), "must go quiet forever after the cap")
    }

    func test_optOut_isPermanent() {
        let now = Date()
        var state = earned(now: now)
        state.optedOut = true
        XCTAssertFalse(state.shouldPrompt(now: now), "\"No thanks\" has to mean never again")
    }

    /// Earning the ask and being able to show it are separate. Until the Stripe
    /// links exist, canPrompt must stay false however earned the user is, so the UI
    /// never renders buttons that go nowhere.
    func test_canPrompt_requiresConfiguredLinks() {
        let now = Date()
        let state = earned(now: now)
        XCTAssertTrue(state.shouldPrompt(now: now), "usage is earned")
        XCTAssertEqual(state.canPrompt(now: now), Donations.isConfigured,
                       "showing the prompt must additionally require real links")
    }

    // MARK: - Coordinator

    /// A scratch defaults domain, so a test run never touches the real counters.
    private func scratchDefaults(_ name: String, seed: DonationState?) throws -> UserDefaults {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        if let seed {
            defaults.set(try JSONEncoder().encode(seed), forKey: "donationState")
        }
        return defaults
    }

    /// The one this pins: reopening the popover must not produce a second ask.
    /// The prompt is recorded when shown, not when acted on, so the cooldown
    /// starts immediately.
    @MainActor
    func test_reopeningPopover_doesNotAskTwice() throws {
        let defaults = try scratchDefaults(#function, seed: earned(now: Date()))
        let coordinator = DonationCoordinator(defaults: defaults)

        coordinator.popoverDidOpen()
        XCTAssertTrue(coordinator.isShowing, "an earned user should see it once")

        coordinator.dismiss()
        coordinator.popoverDidOpen()
        XCTAssertFalse(coordinator.isShowing, "closing and reopening must not re-ask")

        // Nor on the next launch.
        let relaunched = DonationCoordinator(defaults: defaults)
        relaunched.popoverDidOpen()
        XCTAssertFalse(relaunched.isShowing)
    }

    @MainActor
    func test_optOut_survivesRelaunch() throws {
        let defaults = try scratchDefaults(#function, seed: earned(now: Date()))
        let coordinator = DonationCoordinator(defaults: defaults)
        coordinator.popoverDidOpen()
        coordinator.optOut()
        XCTAssertFalse(coordinator.isShowing)

        let relaunched = DonationCoordinator(defaults: defaults)
        relaunched.popoverDidOpen()
        XCTAssertFalse(relaunched.isShowing, "\"No thanks\" must outlive the process")
    }

    /// Nothing to show someone who installed it this morning.
    @MainActor
    func test_freshInstall_coordinatorStaysQuiet() throws {
        let defaults = try scratchDefaults(#function, seed: nil)
        let coordinator = DonationCoordinator(defaults: defaults)
        coordinator.recordToggle()
        coordinator.popoverDidOpen()
        XCTAssertFalse(coordinator.isShowing)
    }

    func test_stateRoundTripsThroughCodable() throws {
        let now = Date()
        let state = earned(now: now)
        let decoded = try JSONDecoder().decode(
            DonationState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(decoded, state, "counters must survive a relaunch")
    }
}
#endif
