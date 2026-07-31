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

# The status item is an SF Symbol, NOT the app icon. WindbarApp.swift renders
# Image(systemName: appModel.menuBarSymbol), which is "fan.fill" while a fan is
# running, so that is what the store page has to show. Compositing the colour app
# icon here made every screenshot promise a menu bar the app never draws.
SYMBOL = 'fan.fill'
SYMBOL_PNG = os.path.join(ROOT, 'screenshots', 'menubar_symbol.png')

SF = '/System/Library/Fonts/SFNS.ttf'

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


def font(size, weight='Regular'):
    """SF Pro at any named weight. The variable font carries Ultralight..Black."""
    f = ImageFont.truetype(SF, size)
    try:
        f.set_variation_by_name(weight)
    except Exception:
        pass
    return f


def wifi(d, x, cy, w=26, colour=(255, 255, 255, 235)):
    """Wi-Fi glyph: three arcs and a dot, drawn rather than faked with text."""
    for i, r in enumerate((w * 0.50, w * 0.34, w * 0.18)):
        d.arc([x - r, cy - r + w * 0.30, x + r, cy + r + w * 0.30],
              start=218, end=322, fill=colour, width=max(2, int(w * 0.11)))
    r = w * 0.055
    d.ellipse([x - r, cy + w * 0.24 - r, x + r, cy + w * 0.24 + r], fill=colour)


def battery(d, x, cy, w=42, level=0.82, colour=(255, 255, 255, 235)):
    h = w * 0.46
    d.rounded_rectangle([x, cy - h / 2, x + w, cy + h / 2], radius=h * 0.30,
                        outline=colour, width=max(2, int(w * 0.05)))
    d.rounded_rectangle([x + w + 2, cy - h * 0.16, x + w + 6, cy + h * 0.16],
                        radius=2, fill=colour)
    pad = w * 0.075
    d.rounded_rectangle([x + pad, cy - h / 2 + pad,
                         x + pad + (w - pad * 2) * level, cy + h / 2 - pad],
                        radius=h * 0.18, fill=colour)


def control_centre(d, x, cy, w=26, colour=(255, 255, 255, 235)):
    """Two toggle pills, the Control Center glyph."""
    lw = max(2, int(w * 0.10))
    for i, knob_left in enumerate((True, False)):
        y = cy - w * 0.20 + i * w * 0.40
        d.rounded_rectangle([x, y - w * 0.14, x + w, y + w * 0.14],
                            radius=w * 0.14, outline=colour, width=lw)
        kx = x + w * 0.14 if knob_left else x + w * 0.86
        d.ellipse([kx - w * 0.07, y - w * 0.07, kx + w * 0.07, y + w * 0.07], fill=colour)


def spotlight(d, x, cy, w=24, colour=(255, 255, 255, 235)):
    r = w * 0.34
    lw = max(2, int(w * 0.10))
    d.ellipse([x - r, cy - r - w * 0.06, x + r, cy + r - w * 0.06], outline=colour, width=lw)
    d.line([x + r * 0.72, cy + r * 0.66 - w * 0.06,
            x + r * 1.35, cy + r * 1.30 - w * 0.06], fill=colour, width=lw)


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


def status_symbol():
    """The menu bar glyph, rendered from the real SF Symbol by export_symbol.swift.

    Shelling out to Swift is the only way to get the actual system glyph: the SF
    Symbols font is not redistributable and Pillow has no access to it.
    """
    import subprocess
    os.makedirs(os.path.dirname(SYMBOL_PNG), exist_ok=True)
    subprocess.run(
        ['swift', os.path.join(ROOT, 'export_symbol.swift'), SYMBOL, '34', 'white', SYMBOL_PNG],
        check=True, capture_output=True)
    return Image.open(SYMBOL_PNG).convert('RGBA')


def menu_bar(img, icon):
    """A real macOS menu bar, not a grey strip.

    Height is 48px because 2880x1800 represents a 1440x900 point screen at 2x, and
    the macOS menu bar is 24pt. The earlier 74px strip was almost twice too tall,
    which is the kind of thing a Mac user notices without being able to name it.

    The left side says "Finder", not "Windbar", and that is deliberate: Windbar sets
    LSUIElement, so it has no menus and never owns the menu bar. It appears only as
    a status item on the right, which is exactly what is drawn here.
    """
    BAR = 48
    img.alpha_composite(Image.new('RGBA', (W, BAR), (250, 252, 255, 30)), (0, 0))
    d = ImageDraw.Draw(img)
    d.line([(0, BAR), (W, BAR)], fill=(255, 255, 255, 28), width=1)

    ink = (255, 255, 255, 240)
    f_menu = font(26, 'Regular')
    f_app  = font(26, 'Bold')
    f_time = font(26, 'Regular')

    # ---- left: Apple logo, active app, its menus
    x = 30
    d.text((x, BAR / 2), '\uf8ff', font=font(30, 'Regular'), fill=ink, anchor='lm')
    x += 40
    d.text((x, BAR / 2), 'Finder', font=f_app, fill=ink, anchor='lm')
    x += d.textlength('Finder', font=f_app) + 30
    for item in ('File', 'Edit', 'View', 'Go', 'Window', 'Help'):
        d.text((x, BAR / 2), item, font=f_menu, fill=ink, anchor='lm')
        x += d.textlength(item, font=f_menu) + 28

    # ---- right: status items, laid out right to left in real macOS order
    cy = BAR / 2
    right = W - 34
    clock = 'Wed 30 Jul  13:45'
    d.text((right, cy), clock, font=f_time, fill=ink, anchor='rm')
    right -= d.textlength(clock, font=f_time) + 34

    spotlight(d, right - 12, cy);        right -= 46
    control_centre(d, right - 26, cy);   right -= 60
    battery(d, right - 42, cy);          right -= 76
    wifi(d, right - 13, cy);             right -= 52

    # ---- the app itself, highlighted the way macOS shows an open menu extra
    ic_h = 30
    ic_w = max(1, round(icon.width * ic_h / icon.height))
    ix = int(right - ic_w)
    d.rounded_rectangle([ix - 11, 4, ix + ic_w + 11, BAR - 4],
                        radius=7, fill=(255, 255, 255, 64))
    img.alpha_composite(icon.resize((ic_w, ic_h), Image.LANCZOS),
                        (ix, int(cy - ic_h / 2)))
    return ix + ic_w // 2, BAR


def paste_popover(img, shot, anchor_x, bar_h=48):
    """Drop the real capture under the menu bar icon, with a soft shadow."""
    target_h = int(H * 0.82)
    scale = target_h / shot.height
    if shot.width * scale > W * 0.40:                 # keep room for the caption
        scale = (W * 0.40) / shot.width
    s = shot.resize((int(shot.width * scale), int(shot.height * scale)), Image.LANCZOS)

    x = int(min(max(anchor_x - s.width / 2, W * 0.60), W - s.width - W * 0.05))
    # A tall popover hangs from the menu bar the way it really does. A short
    # window (Settings) centres instead, or the frame goes bottom-heavy.
    y = bar_h + 14 if s.height > H * 0.55 else int((H - s.height) / 2)
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
    """Headline in Black, subhead in Medium.

    Bold was too polite. Store screenshots get skimmed in about a second, so the
    headline needs the heaviest weight the family has, and the subhead needs Medium
    rather than Regular to stay legible once Apple scales the frame down in the
    product page carousel.
    """
    d = ImageDraw.Draw(img)
    left, max_w = int(W * 0.065), int(right_edge - W * 0.065 - W * 0.05)

    # Auto-fit the headline instead of picking a fixed size. At a fixed 146px every
    # headline wrapped and left an orphan word on its own line ("all.", "needed.",
    # "stays"), which looks like a mistake and costs more than the extra few points
    # of size were worth. Shrink until the line breaks written in CAPTIONS are the
    # only line breaks that happen.
    head_lines = head.split('\n')
    size = 146
    while size > 84:
        fh = font(size, 'Black')
        if max(d.textlength(ln, font=fh) for ln in head_lines) <= max_w:
            break
        size -= 4
    fh = font(size, 'Black')
    fs = font(52, 'Medium')
    sub_lines  = wrap(d, sub, fs, max_w)
    LH_H, LH_S, GAP = int(size * 1.11), 74, 52
    block = len(head_lines) * LH_H + GAP + len(sub_lines) * LH_S
    y = (H - block) // 2

    for ln in head_lines:
        # Soft shadow so white type survives the lighter areas of the backdrop.
        d.text((left + 4, y + 5), ln, font=fh, fill=(2, 12, 30, 120))
        d.text((left, y), ln, font=fh, fill=(255, 255, 255, 255))
        y += LH_H
    y += GAP

    # Accent bar ties the subhead to the app's own blue.
    bar_top = y + 12
    bar_bot = y + len(sub_lines) * LH_S - 14
    d.rounded_rectangle([left, bar_top, left + 7, bar_bot], radius=4,
                        fill=(95, 181, 247, 210))
    for ln in sub_lines:
        d.text((left + 30, y), ln, font=fs, fill=(206, 231, 248, 245))
        y += LH_S


def main():
    if not os.path.isdir(RAW):
        sys.exit('No raw captures. Create %s and put 01.png, 02.png ... in it.\n'
                 'Capture with Cmd-Shift-4 then Space, clicking the popover.' % RAW)
    os.makedirs(OUT, exist_ok=True)
    icon = status_symbol()
    built = 0
    for num, head, sub in CAPTIONS:
        src = os.path.join(RAW, '%s.png' % num)
        if not os.path.exists(src):
            print('  skip %s (no %s.png yet)' % (num, num)); continue
        img = backdrop()
        anchor, bar_h = menu_bar(img, icon)
        x = paste_popover(img, Image.open(src).convert('RGBA'), anchor, bar_h)
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
