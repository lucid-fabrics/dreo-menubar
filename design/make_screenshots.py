#!/usr/bin/env python3
"""Build Mac App Store screenshots from raw popover captures.

WHY THIS EXISTS
---------------
Windbar's UI is a ~320pt vertical popover. The Mac App Store wants wide landscape
frames (2880x1800). Dropping a narrow popover into that leaves most of the frame
empty, which is the standard menu bar app problem. So each frame is composited:
a desktop backdrop, a macOS menu bar strip with the Windbar icon lit up, the real
popover anchored under it on the right, and the caption in the space on the left.

Apple requires the REAL UI. Everything here is framing around a genuine capture,
never a redrawn or faked interface.

USAGE
-----
  1. Capture each popover with Cmd-Shift-4 then Space (click the popover).
     Save as design/screenshots/raw/01.png, 02.png, ...
  2. python3 design/make_screenshots.py
  3. Output lands in fastlane/screenshots/en-US/

Copy lives in CAPTIONS below. Edit there, not in the image editor.
"""
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import numpy as np, os, sys

W, H = 2880, 1800                      # Apple's largest macOS size; scales down cleanly
ROOT = os.path.dirname(os.path.abspath(__file__))
RAW  = os.path.join(ROOT, 'screenshots', 'raw')
OUT  = os.path.abspath(os.path.join(ROOT, '..', 'fastlane', 'screenshots', 'en-US'))
ICON = os.path.abspath(os.path.join(
    ROOT, '..', 'Windbar', 'Resources', 'Assets.xcassets',
    'AppIcon.appiconset', 'icon_512x512@2x.png'))

SF_BOLD = '/System/Library/Fonts/SFNS.ttf'
SF_REG  = '/System/Library/Fonts/SFNS.ttf'

# Caption copy. Formula: verb + benefit + result, 3 to 6 words, benefit not feature.
# Order matters more than anything else here: the first three frames carry roughly
# 70% of conversion weight and about half of visitors never scroll past the second.
# Arc is Value -> Emotion -> Proof -> Depth -> Trust.
CAPTIONS = [
    ("01", "One click. Fan on.",
           "Every fan you own, living in the menu bar."),
    ("02", "Or never click at all.",
           "Give each fan its own key. Bedroom on one, office on another, "
           "or drive them from Shortcuts and Stream Deck."),
    ("03", "Set up a new fan.\nNo phone needed.",
           "Your Mac talks to it over Bluetooth and puts it straight "
           "onto your WiFi."),
    ("04", "Your password stays\non your Mac.",
           "Kept in the Keychain and sent only to Dreo. No account with us, "
           "no tracking, no analytics."),
]


def font(path, size, bold=False):
    f = ImageFont.truetype(path, size)
    if bold:
        try:
            f.set_variation_by_name('Bold')
        except Exception:
            pass
    return f


def backdrop():
    """Deep desktop gradient in the app's own blue-teal family."""
    yy, xx = np.mgrid[0:H, 0:W]
    t = (xx / W) * 0.6 + (1 - yy / H) * 0.4
    c0, c1 = np.array([9, 20, 46]), np.array([17, 74, 96])
    g = np.zeros((H, W, 3), np.float32)
    for i in range(3):
        g[..., i] = c0[i] + (c1[i] - c0[i]) * t
    img = Image.fromarray(g.astype(np.uint8), 'RGB').convert('RGBA')
    glow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([W * 0.42, -H * 0.35, W * 1.25, H * 0.75],
                                 fill=(60, 190, 210, 46))
    return Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(160)))


def menu_bar(img, icon):
    """Translucent macOS menu bar with the Windbar icon highlighted.

    This is the bit that tells a Mac user 'menu bar app' before they read a word.
    """
    bar_h = 74
    strip = Image.new('RGBA', (W, bar_h), (255, 255, 255, 26))
    img.alpha_composite(strip, (0, 0))
    d = ImageDraw.Draw(img)

    ic = icon.resize((46, 46), Image.LANCZOS)
    ix = int(W * 0.735)
    # Selected-item highlight, exactly what macOS shows while a popover is open.
    d.rounded_rectangle([ix - 16, 6, ix + 62, bar_h - 6], radius=9,
                        fill=(255, 255, 255, 62))
    img.alpha_composite(ic, (ix, 14))

    f = font(SF_REG, 30)
    for label, x in (("100%", 0.80), ("Wed 14:22", 0.875)):
        d.text((W * x, 22), label, font=f, fill=(255, 255, 255, 210))
    return ix + 23   # x centre of the icon, so the popover can point at it


def paste_popover(img, shot, anchor_x):
    """Drop the real capture under the menu bar icon, with a soft shadow."""
    target_h = int(H * 0.70)
    scale = target_h / shot.height
    if shot.width * scale > W * 0.36:                 # keep room for the caption
        scale = (W * 0.36) / shot.width
    s = shot.resize((int(shot.width * scale), int(shot.height * scale)), Image.LANCZOS)

    x = int(min(max(anchor_x - s.width / 2, W * 0.60), W - s.width - W * 0.05))
    # A tall popover hangs from the menu bar the way it really does. A short
    # window (Settings) centres instead, or the frame goes bottom-heavy.
    y = 96 if s.height > H * 0.55 else int((H - s.height) / 2)
    sh = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle([x + 10, y + 22, x + s.width + 10, y + s.height + 22],
                                         radius=28, fill=(0, 0, 0, 150))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(46)))
    img.alpha_composite(s, (x, y))
    return x


def wrap(d, text, f, max_w):
    out = []
    for para in text.split('\n'):
        line = ''
        for word in para.split():
            probe = (line + ' ' + word).strip()
            if d.textlength(probe, font=f) <= max_w or not line:
                line = probe
            else:
                out.append(line); line = word
        out.append(line)
    return out


def caption(img, head, sub, right_edge):
    d = ImageDraw.Draw(img)
    left, max_w = int(W * 0.065), int(right_edge - W * 0.065 - W * 0.05)
    fh, fs = font(SF_BOLD, 132, bold=True), font(SF_REG, 54)

    head_lines = wrap(d, head, fh, max_w)
    sub_lines  = wrap(d, sub, fs, max_w)
    block = len(head_lines) * 150 + 46 + len(sub_lines) * 76
    y = (H - block) // 2

    for ln in head_lines:
        d.text((left + 3, y + 4), ln, font=fh, fill=(0, 0, 0, 110))   # lift off the bg
        d.text((left, y), ln, font=fh, fill=(255, 255, 255, 255))
        y += 150
    y += 46
    for ln in sub_lines:
        d.text((left, y), ln, font=fs, fill=(196, 226, 244, 240))
        y += 76


def main():
    if not os.path.isdir(RAW):
        sys.exit('No raw captures. Create %s and put 01.png, 02.png ... in it.\n'
                 'Capture with Cmd-Shift-4 then Space, clicking the popover.' % RAW)
    os.makedirs(OUT, exist_ok=True)
    icon = Image.open(ICON).convert('RGBA')
    built = 0
    for num, head, sub in CAPTIONS:
        src = os.path.join(RAW, '%s.png' % num)
        if not os.path.exists(src):
            print('  skip %s (no %s.png yet)' % (num, num)); continue
        img = backdrop()
        anchor = menu_bar(img, icon)
        x = paste_popover(img, Image.open(src).convert('RGBA'), anchor)
        caption(img, head, sub, x)
        dest = os.path.join(OUT, '%s_windbar.png' % num)
        img.convert('RGB').save(dest, 'PNG')
        print('  built %s  %s' % (dest, head.replace('\n', ' ')))
        built += 1
    print('\n%d screenshot(s) in %s' % (built, OUT))
    if built:
        print('Set skip_screenshots to false in fastlane/Fastfile, then '
              'bundle exec fastlane mac push_metadata')


if __name__ == '__main__':
    main()
