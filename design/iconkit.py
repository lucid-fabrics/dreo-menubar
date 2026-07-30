"""Drawing helpers for a crafted (not AI-rendered) macOS app icon.

Everything is drawn at SS x resolution and downsampled once at the end, which is
what gives clean curves instead of the soft fringes you get from keying a render.
"""
from PIL import Image, ImageDraw, ImageFilter
import numpy as np

SS = 4  # supersample factor

def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

def linear_gradient(size, c0, c1, angle=0.65):
    """Diagonal gradient. angle blends x vs y contribution."""
    w = h = size
    yy, xx = np.mgrid[0:h, 0:w]
    t = (xx / w) * angle + (1 - yy / h) * (1 - angle)
    t = np.clip(t, 0, 1)
    out = np.zeros((h, w, 3), np.float32)
    for i in range(3):
        out[..., i] = c0[i] + (c1[i] - c0[i]) * t
    return Image.fromarray(out.astype(np.uint8), 'RGB').convert('RGBA')

def radial_light(size, cx, cy, radius, colour, strength):
    """Soft radial glow, used for the light source on the background."""
    yy, xx = np.mgrid[0:size, 0:size]
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / radius
    a = np.clip(1 - d, 0, 1) ** 2 * strength
    rgba = np.zeros((size, size, 4), np.float32)
    for i in range(3):
        rgba[..., i] = colour[i]
    rgba[..., 3] = a * 255
    return Image.fromarray(rgba.astype(np.uint8), 'RGBA')

def squircle_mask(size, ratio=0.2237):
    m = Image.new('L', (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size - 1, size - 1],
                                        radius=int(size * ratio), fill=255)
    return m

def ring_gradient(size, box, c_top, c_bot):
    """Vertical gradient clipped to an ellipse: gives metal-looking bezels."""
    x0, y0, x1, y1 = box
    w, h = int(x1 - x0), int(y1 - y0)
    yy = np.mgrid[0:h, 0:w][0]
    t = yy / max(h - 1, 1)
    g = np.zeros((h, w, 3), np.float32)
    for i in range(3):
        g[..., i] = c_top[i] + (c_bot[i] - c_top[i]) * t
    layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    patch = Image.fromarray(g.astype(np.uint8), 'RGB').convert('RGBA')
    mask = Image.new('L', (w, h), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, w - 1, h - 1], fill=255)
    layer.paste(patch, (int(x0), int(y0)), mask)
    return layer

def drop_shadow(shape_layer, blur, offset=(0, 0), colour=(0, 14, 46), opacity=140):
    a = np.asarray(shape_layer)[..., 3].astype(np.float32) / 255.0
    sh = np.zeros(a.shape + (4,), np.float32)
    for i in range(3):
        sh[..., i] = colour[i]
    sh[..., 3] = a * opacity
    img = Image.fromarray(sh.astype(np.uint8), 'RGBA').filter(ImageFilter.GaussianBlur(blur))
    if offset != (0, 0):
        img = Image.fromarray(np.roll(np.asarray(img), offset[1], axis=0))
        img = Image.fromarray(np.roll(np.asarray(img), offset[0], axis=1))
    return img

def cylinder_shade(size, x0, x1, light=0.34):
    """Horizontal cosine shading: makes a flat rounded-rect read as a cylinder.
    light = where the highlight band sits across the width (0..1)."""
    xx = np.mgrid[0:size, 0:size][1].astype(np.float32)
    t = np.clip((xx - x0) / max(x1 - x0, 1), 0, 1)
    # bright band at `light`, falling off to both edges
    shade = np.cos((t - light) * np.pi * 1.15)
    shade = np.clip(shade, -1, 1)
    return shade  # -1 .. 1

def apply_shade(layer, shade, mask, warm=(255, 255, 255), cool=(120, 150, 186), amount=1.0):
    """Blend a layer toward white where shade>0 and toward a cool shadow where shade<0."""
    a = np.asarray(layer).astype(np.float32)
    m = (np.asarray(mask).astype(np.float32) / 255.0) * amount
    s = shade
    for i in range(3):
        hi = warm[i] - a[..., i]
        lo = a[..., i] - cool[i]
        a[..., i] += np.where(s > 0, hi * s * 0.55, -lo * (-s) * 0.62) * m
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), 'RGBA')

def rim_light(mask, dx, dy, blur, colour=(200, 240, 255), opacity=170):
    """Bright edge on one side: shift the silhouette and keep what pokes out."""
    m = np.asarray(mask).astype(np.float32)
    shifted = np.roll(np.roll(m, dy, axis=0), dx, axis=1)
    edge = np.clip(m - shifted, 0, 255)
    out = np.zeros(m.shape + (4,), np.float32)
    for i in range(3):
        out[..., i] = colour[i]
    out[..., 3] = edge / 255.0 * opacity
    return Image.fromarray(out.astype(np.uint8), 'RGBA').filter(ImageFilter.GaussianBlur(blur))

def ground_reflection(layer, floor_y, height, fade=0.30, blur=6):
    """Flipped, fading copy below the floor line so objects sit on a surface."""
    a = np.asarray(layer)
    h, w = a.shape[:2]
    top = max(int(floor_y - height), 0)
    strip = Image.fromarray(a[top:int(floor_y)], 'RGBA').transpose(Image.FLIP_TOP_BOTTOM)
    sa = np.asarray(strip).astype(np.float32).copy()
    n = sa.shape[0]
    ramp = np.linspace(fade, 0.0, n)[:, None]
    sa[..., 3] *= ramp
    out = np.zeros_like(a, np.float32)
    end = min(int(floor_y) + n, h)
    out[int(floor_y):end] = sa[:end - int(floor_y)]
    return Image.fromarray(out.astype(np.uint8), 'RGBA').filter(ImageFilter.GaussianBlur(blur))
