# App icon

The icon is **drawn in code**, not exported from a design tool and not AI-generated. That is
deliberate: earlier attempts using image generation gave washed-out colours, soft fringes from
keying the background out, and no way to make a precise change. Here every dimension, colour and
lighting term is a parameter.

## Regenerate

```bash
python3 -m pip install pillow numpy
cd design && python3 draw_duo2.py          # writes duo3_master.png (1024, transparent surround)
```

Then slice it into the asset catalog:

```python
from PIL import Image
src = Image.open('duo3_master.png')
for size, scale in [(16,1),(16,2),(32,1),(32,2),(128,1),(128,2),(256,1),(256,2),(512,1),(512,2)]:
    px = size*scale
    src.resize((px,px), Image.LANCZOS).save(
        f"../Windbar/Resources/Assets.xcassets/AppIcon.appiconset/"
        f"icon_{size}x{size}{'@2x' if scale==2 else ''}.png")
```

`draw_duo2.py` already emits the squircle and the transparent margin at Apple's 824-of-1024 grid,
so do **not** re-mask the output.

## What is in it

A tower fan on the left and an air circulator on the right, the two shapes Dreo is known for,
drawn as the product category rather than as copies of specific models. Imitating a particular
product's design would add trade-dress exposure on top of the trademark question that already
keeps "Dreo" out of the app name.

`iconkit.py` holds the reusable pieces:

| Helper | Why it matters |
|---|---|
| `cylinder_shade` + `apply_shade` | cosine highlight band across a shape, so a flat rounded rect reads as a cylinder instead of a sticker |
| `rim_light` | bright edge on the lit side; this is what separates the objects from the background |
| `ground_reflection` | fading flipped copy below the floor line, so they stand on a surface |
| `drop_shadow` | soft shadow from any layer's alpha |
| `squircle_mask` | Apple's continuous-corner tile |

Everything is drawn at 4x and downsampled once at the end. That single downsample is what gives
clean curves; drawing at final size produces visibly stepped edges.

## Tuning

Common knobs, all near the top of `draw_duo2.py`:

- `TW`, `TH`, `TCX` - tower width, height, horizontal position
- `CCX`, `CR` - circulator centre and radius
- `FLOOR` - the shared floor line both objects stand on
- the `linear_gradient(...)` call - background palette
- `fade=` in `ground_reflection` - reflection strength
- blade count is the `range(5)` loop; slot count is the `range(5)` in the grille block

## Known limits

Below about 32px the two objects merge into one blob. That is inherent to having two subjects in
one icon and cannot be shaded away. A single-object variant reads better small; the pair was the
deliberate choice because it communicates "these are your fans" at listing size.
