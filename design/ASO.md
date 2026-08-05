# App Store keyword research

## The rule that governs everything here

App Store search indexes the **app name and the keyword field**. It does **not** index the
description. Anything you want found must be in one of those two, and Apple combines words across
both when matching, so repeating a word in the keyword field that already appears in the name wastes
characters.

**Subtitle does NOT exist for macOS apps.** `fastlane/metadata/en-US/subtitle.txt` looks like it
should work, and `deliver` silently accepts it and reports success, but the App Store Connect API
rejects `subtitle` outright for macOS `appStoreVersionLocalizations` (`'subtitle' is not an attribute
on the resource`, confirmed 2026-08-05 with a direct PATCH). Deliver just drops the field for this
platform without warning. Found after `dreo` and `fan`, the two strongest keywords measured, had been
sitting unindexed on the live listing for over a week because both were "covered by the subtitle"
according to this doc, and the subtitle was never actually live. Subtitle is iOS/iPadOS/tvOS only;
`subtitle.txt` was deleted rather than left around to mislead the next release.

Windbar's app **name** still contributes for free: `windbar` (7 of 30 chars used). Everything else,
including `dreo` and `fan`, has to go in the keyword field.

Limits: name 30 chars, keywords 100. Comma-separated, **no spaces after commas**, since spaces count.

## Tooling

Research runs through the **Astro** MCP server, registered at user scope:

```bash
claude mcp add --scope user --transport http astro http://127.0.0.1:8089/mcp
```

Astro is a native macOS app that serves MCP on port 8089 itself, so **the tools only resolve while
the Astro app is running**. If they vanish, open Astro.

## Method

1. `add_app` for the app. Windbar is currently a **temporary placeholder** (app id `101`, platform
   `mac`) because Apple cannot be queried for an unreleased app. **After release, re-add with the
   real ID `6796354199`** to get true ranking positions instead of estimates.
2. `add_keywords` with candidate terms. Returns popularity and difficulty per term.
3. Keep terms that are both **trafficked and honest**. Popularity 5 is the floor value and means
   nobody searches it.
4. `search_app_store` on a term shows who actually ranks, which reveals search *intent*.
5. Re-check before each release. Popularity scores move.

## Measured results, July 2026, US store, Mac platform

Worth keeping, high traffic and accurate for this app:

| Keyword | Popularity | Difficulty | Note |
|---|---|---|---|
| `shortcuts` | 67 | 48 | best find; the app really is built for Shortcuts and Stream Deck |
| `home` | 66 | 79 | high traffic, hard |
| `remote` | 65 | 81 | high traffic, hard |
| `breeze` | 59 | 45 | second best find, thematically perfect and uncontested |
| `fan` | 57 | 60 | in the keyword field, see the subtitle note above |
| `switch` | 56 | 53 | |
| **`dreo`** | **54** | **42** | **best ratio of anything tested, in the keyword field** |
| `wifi` | 52 | 70 | |
| `bluetooth` | 50 | 47 | accurate, the app pairs over BLE |
| `devices` | 26 | 40 | |
| `gadget` | 20 | 21 | cheap |
| `iot` | 17 | 21 | cheap |
| `desk` | 12 | 23 | cheap |

Deliberately **excluded despite high traffic**, because the app does not do these and misleading
keywords earn rejections and one-star reviews: `widget` (70, no widget), `ac` (50) and
`air conditioner` (19) and `temperature` (35) (controls none of them), `dashboard` (35), `monitor`,
`smart plug`.

**Dead, popularity 5, nobody searches them.** These were the intuitive guesses and every one is
worthless: `tower fan`, `air circulator`, `circulator`, `wifi fan`, `bluetooth fan`, `smart fan`,
`oscillating fan`, `fan speed`, `menu bar`, `menubar`, `hotkey`, `cooling`.

That list is the lesson: choosing keywords by reasoning about what the app does produces dead terms.
Measure them.

## Search intent check

`search_app_store` for `fan` on Mac returns CPU thermal monitors (Temperature Gauge, iStats X,
system stat tools). Mac users searching "fan" want fan-speed control for their laptop, **not** a
smart home fan. That mismatch is why the listing leans on `dreo` and `breeze` rather than fighting
for a term whose intent is wrong.

`smart fan` returns WhatsApp and a printer app, meaning Apple has nothing relevant indexed for it.

## Current live values

- Name: `Windbar`
- Subtitle: `Menu bar control for Dreo fans` (30/30)
- Keywords: `shortcuts,breeze,bluetooth,switch,summer,devices,wifi,home,remote,iot,gadget,desk,toggle,smart` (94/100)

Edit these in `fastlane/metadata/en-US/`, then `bundle exec fastlane mac push_metadata`. The files
are the source of truth; anything typed into the App Store Connect website gets overwritten.
