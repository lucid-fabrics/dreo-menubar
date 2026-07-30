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

## The five frames

Arc: **Value → Emotion → Proof → Depth → Trust.** The first three are the ones that matter.

| # | Capture | Headline | Why this one, here |
|---|---|---|---|
| 01 | Popover, two fans, both **on**, controls visible | **One click. Fan on.** | Core promise in under a second. Names the whole product benefit with four words. |
| 02 | Popover with the Settings shortcut pane, or the popover with a keycap overlay | **Or never click at all.** | The escalation. Frame 1 sells convenience, frame 2 sells *zero effort*, which is the real hook. |
| 03 | The "Add a Device" pairing wizard | **Set up a new fan. No phone needed.** | The differentiator nothing else on the store does. This is the proof you are not a toy. |
| 04 | Settings, per-device shortcuts assigned | **One key per room.** | Depth, for the buyer who is already interested. Mentions Shortcuts and Stream Deck. |
| 05 | Settings or the login screen, signed in | **Your password never leaves your Mac.** | Trust. A third-party client asking for smart-home credentials must answer this. |

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

## Capturing

1. **Rename your fans in the Dreo app first.** "Bedroom" and "Office" look like a real setup;
   "Tower Fan" and "Air Circulator" look like a demo. This matters more than it sounds: the research
   is blunt that placeholder-looking content costs conversion.
2. **Turn the fans on** before capturing, so toggles read blue and speeds are non-zero. Never
   capture an empty device list.
3. Capture with **Cmd-Shift-4, then Space**, then click the window. That yields a transparent
   background with the real macOS shadow.
4. Save into `design/screenshots/raw/` as `01.png` through `05.png`.
5. Run:

   ```bash
   python3 design/make_screenshots.py
   ```

6. Flip `skip_screenshots` to `false` in `fastlane/Fastfile` (both `release` and `push_metadata`),
   then `bundle exec fastlane mac push_metadata`.

## Does the UI need changing first?

Mostly no. The popover is dense, legible and looks like a real Mac app. Three things are worth
knowing before you shoot:

1. **`docs/menubar.png` and `docs/pairing.png` in the README are stale.** They still show
   "Quit DreoBar". The code is correct (`MenuBarView.swift:79` says Windbar); the images predate the
   rename. Regenerate them from the same captures you take for the store.
2. **The empty state is a liability, not a bug.** `MenuBarView.swift:26` shows a `fan.slash` state
   when no devices are bound. Correct behaviour, but never let it into a screenshot.
3. **Frame 02 has nothing in the UI that visibly shows a hotkey firing.** Either capture the
   Settings shortcut recorder mid-assignment, or overlay a keycap graphic in the composite. That is
   a screenshot-design problem, not a reason to change the app.

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
