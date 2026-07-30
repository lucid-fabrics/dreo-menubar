# App Store screenshots

## What the research actually says

Sources at the bottom. The findings that changed the design here:

- **The first three frames carry roughly 70% of conversion weight**, and about half of visitors
  never scroll past the second one. Average time on a product page is about seven seconds.
- **Captions lift conversion measurably.** Screenshots with bold, clear text overlays outperform
  bare UI captures. A single screenshot change moving conversion 5 to 10% is normal.
- **Benefit, not feature.** Every caption should answer "what is in it for me". "Track your workouts
  effortlessly" beats "Workout tracker app". Lead with the outcome.
- **3 to 6 words per headline.** Verb + benefit + result. Crowded layouts lose to short ones.
- **Never show an empty or placeholder state.** A lifeless screenshot reads as a lifeless app. Show
  it as it looks after a week of real use.
- **Apple requires the real UI.** Framing and captions around a genuine capture are fine; a redrawn
  or idealised interface is not.
- A strong set can move install conversion 20 to 35%.

## The menu bar problem, and how this set solves it

Windbar's UI is a ~320pt vertical popover. The Mac App Store wants 2880x1800 landscape. Dropping
the popover straight into that frame leaves most of it empty and looks amateur, which is the
standard difficulty for menu bar apps.

`design/make_screenshots.py` composites instead: a desktop backdrop in the app's own blue-teal
palette, a translucent macOS menu bar strip with the Windbar icon **highlighted** the way macOS
shows it while a popover is open, the real capture anchored underneath it on the right, and the
caption occupying the empty left half.

The lit menu bar icon is doing real work. It tells a Mac user "this is a menu bar app" before they
read a single word.

## The four frames

Arc: **Value → Emotion → Proof → Trust.** The first three are the ones that matter.

| # | View | Headline | Why this one, here |
|---|---|---|---|
| 01 | Menu bar popover, two fans, both **on** | **One click. Fan on.** | Core promise in under a second. The whole benefit in four words. |
| 02 | Settings, shortcut recorder | **Or never click at all.** | The escalation. Frame 1 sells convenience, frame 2 sells *zero effort*, which is the real hook. |
| 03 | The "Add a Device" pairing wizard | **Set up a new fan. No phone needed.** | The differentiator nothing else on the store does. Proof this is not a toy. |
| 04 | The real sign-in screen | **Your password stays on your Mac.** | Trust. A third-party client asking for smart-home credentials must answer this, and being upfront that a Dreo account is needed beats a one-star review from someone who found out after paying. |

Copy lives in `CAPTIONS` at the top of `make_screenshots.py`. Edit it there.

### Why these words

- **"One click. Fan on."** is outcome-first and needs no explanation. The rejected alternative,
  "Menu bar control for your fans", is a feature description and asks the reader to do the work of
  imagining the benefit.
- **"Or never click at all."** deliberately builds on frame 1 rather than restarting. Reading the
  set in order tells a story; each frame standing alone as an unrelated feature does not.
- **"No phone needed."** is the loss being removed. Getting up and hunting for a phone to change a
  fan three feet away is the actual pain, and it is worth naming.
- Nothing says "best", "powerful" or "seamless". Hyperbole reads as noise.

## Building them

```bash
./design/render_screenshots.sh          # renders the UI, then composites the frames
bundle exec fastlane mac push_metadata  # uploads listing text and screenshots
```

Fixture device names are "Bedroom" and "Office", not "Tower Fan" and "Air Circulator", and both fans
are **on** with non-zero speeds. That is deliberate: the research is blunt that placeholder-looking
content and empty states cost conversion. Change them in `fixtureDevices()` in the harness.

## Does the UI need changing first?

Mostly no. The popover is dense, legible and looks like a real Mac app. Three things are worth
knowing before you shoot:

1. **`docs/menubar.png` and `docs/pairing.png` in the README were stale**, still showing
   "Quit DreoBar" from before the rename. They are now regenerated from the same render, so rerun
   `render_screenshots.sh` and copy `raw/01.png` and `raw/03.png` over them after any UI change.
2. **The empty state is a liability, not a bug.** `MenuBarView.swift:26` shows a `fan.slash` state
   when no devices are bound. Correct behaviour, but never let it into a screenshot.
3. **Nothing in the UI visibly shows a hotkey firing.** Frame 02 therefore uses the Settings
   shortcut recorder, which is the closest honest depiction. A keycap overlay in the composite would
   be the next improvement. That is a screenshot-design problem, not a reason to change the app.

Do not redesign the app for the store. Apple wants the real interface, and the UI is already good.

## After launch

Use **Product Page Optimization** in App Store Connect to A/B the first frame. It is the highest
leverage single test available, given frame 1 alone carries most of the decision.

## Sources

- [AppFollow, ASO screenshots best practices 2026](https://appfollow.io/blog/aso-screenshots-best-practices)
- [Screenhance, what actually drives downloads 2026](https://screenhance.com/blog/aso-screenshot-best-practices-2026)
- [Screenhance, state of App Store screenshots 2026](https://screenhance.com/blog/state-of-app-store-screenshots-2026)
- [TheAppLaunchpad, screenshot guidelines 2026](https://theapplaunchpad.com/blog/app-store-screenshot-guidelines/)
- [LazyScreenshots, Mac app screenshots sizes and guidelines](https://www.lazyscreenshots.com/blog/app-store-screenshots-mac/)
- [ScreenshotOtter, captions that convert](https://screenshototter.com/blog/app-store-screenshot-captions)
- [Christian Tietze, assembling menu bar app screenshots for the Mac App Store](https://christiantietze.de/posts/2022/04/menu-bar-screenshots/)

---

## Update: these are now generated, not hand-captured

`design/render_screenshots.sh` does the whole job:

```bash
./design/render_screenshots.sh
```

It renders the **real UI** with fixture devices (Bedroom and Office, fans on, authentic control
schemas pulled from the bundled `DeviceTemplates.json`), then composites the store frames. No Dreo
account and no hardware required, and it reruns after any UI change instead of rotting.

### How it works

`WindbarTests/ScreenshotHarness.swift` builds an `AppModel` through the same dependency injection
the unit tests use, so **the shipping app gains nothing and ships nothing extra**. It is skipped
unless `WINDBAR_SHOT_DIR` is set, so normal and CI test runs ignore it.

### Two traps, both already paid for

**SwiftUI's `ImageRenderer` cannot draw AppKit-backed controls.** Every `Toggle` rendered as a
yellow "prohibited" placeholder and the popover had no background, because its material normally
comes from the window. The harness uses `NSHostingView` + `cacheDisplay(in:to:)` instead, which
runs the genuine AppKit drawing path. Switches, sliders and segmented controls all come out right,
and it needs no Screen Recording permission.

**The host app is sandboxed**, so the test process cannot write outside its container: an arbitrary
`WINDBAR_SHOT_DIR` fails with "You don't have permission to save the file". The harness writes to
its sandbox temp directory and prints the paths; the shell script copies them out.

Also note `xcodebuild` does not forward shell environment to the test process. Variables need the
`TEST_RUNNER_` prefix, which the script handles.

### Four frames, four different views

An earlier five-frame cut repeated `MenuBarView` and `SettingsView` twice with only the caption
changed. That wastes the slots carrying most of the conversion weight. The set is now one view each:
menu bar popover, Settings shortcuts, the pairing wizard, and the real sign-in screen for the trust
frame. Being upfront that a Dreo account is required beats a one-star review from someone who found
out after paying.
