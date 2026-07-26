#!/usr/bin/env python3
"""Lift the bat wings off Gothicvania's demon and bake them into a wing sprite strip.

    python tools/build_wings.py

WHY THIS SOURCE. The Wings evolved trait was a procedural polygon in body_marks.gd —
a flat quad that beat up and down. It read as a placeholder because it was one. The
replacement had to satisfy three things at once: side-on (this is a side-scroller, so
a top-down or 3/4 wing is useless), actually animated, and drawn by ansimuz — the same
artist as the Gothic hero the player wears. Anything from another artist would sit on
the character at a different outline weight and palette and look pasted on.

demon-idle.png answers all three. The demon is a caped figure with large bat wings, and
its 6-frame idle is a full wing beat: up-stroke, spread, down-stroke.

HOW THE WINGS ARE SEPARATED. The sprite has a 9-colour palette, and the wing membrane
owns three of them that the body never uses:

    (98,22,25)  membrane        (71,12,36)  membrane shadow
    (152,62,29) bone and claw   <- also the outline of the demon's chained skull props

Colour alone therefore over-selects, so masked pixels are grouped into connected
components and only the largest — the near wing — is kept. It runs 1200-2000 px against
30-120 for a skull, so the choice is never close. See the note in extract() for why one
wing rather than the authored pair.

Frame 3 is skipped. It is the wings-tucked pose, which sits at a bounding box the other
frames cannot share, and a tuck belongs to an idle demon rather than to wings on a
running character.

WHY THE OUTPUT IS GREYSCALE. Wings are tinted at draw time to whatever colour the trait
system has assigned, exactly as the procedural version was. Multiplying a tint into dark
maroon yields dark maroon, so the three palette entries are flattened to three levels of
white and the shading survives the modulate. Setting wing_color to a warm red in
body_marks.gd reproduces the demon's original colouring.

Nothing is drawn or invented here — pixels are masked, repositioned, and levelled.
Output is a single sprite strip; the source pack is left untouched.
"""
from __future__ import annotations

import glob
import os
import sys

try:
    from PIL import Image
except ImportError:  # pragma: no cover
    sys.exit("Pillow is required:  python -m pip install --user Pillow")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACK = os.path.join(ROOT, "art-resources", "02_ansimuz_gothicvania_collection")
OUT_PNG = os.path.join(ROOT, "assets", "sprites", "player", "wings_bat.png")

FRAME_W, FRAME_H = 160, 144
# Membrane, membrane shadow, bone -> the levels they become in the greyscale output.
WING_LEVELS = {(71, 12, 36): 120, (98, 22, 25): 190, (152, 62, 29): 255}
MIN_COMPONENT = 200
# Up-stroke, spread, down-stroke. See the note on frame 3 above.
USE_FRAMES = [0, 1, 2]
# Where the wings meet the demon's back, in source-frame pixels. body_marks.gd anchors
# the strip by this point, so the wings stay pinned to the shoulders as they beat
# instead of sliding around the body.
PIVOT = (80, 52)


def load_demon() -> Image.Image:
    hits = [
        p for p in glob.glob(os.path.join(PACK, "**", "demon-idle.png"), recursive=True)
        if not os.path.basename(p).startswith("._")  # macOS resource forks
    ]
    if not hits:
        sys.exit(f"demon-idle.png not found under {PACK}")
    return Image.open(hits[0]).convert("RGBA")


def components(mask: list[list[bool]], w: int, h: int) -> list[list[tuple[int, int]]]:
    """8-connected blobs of masked pixels. Iterative — a wing is ~2000 px and deep
    recursion on that is a needless way to lose."""
    seen = [[False] * w for _ in range(h)]
    found: list[list[tuple[int, int]]] = []
    for y in range(h):
        for x in range(w):
            if not mask[y][x] or seen[y][x]:
                continue
            stack = [(x, y)]
            seen[y][x] = True
            blob: list[tuple[int, int]] = []
            while stack:
                cx, cy = stack.pop()
                blob.append((cx, cy))
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = cx + dx, cy + dy
                        if 0 <= nx < w and 0 <= ny < h and mask[ny][nx] and not seen[ny][nx]:
                            seen[ny][nx] = True
                            stack.append((nx, ny))
            found.append(blob)
    return found


def extract(demon: Image.Image, index: int) -> Image.Image:
    frame = demon.crop((index * FRAME_W, 0, (index + 1) * FRAME_W, FRAME_H))
    px = frame.load()
    mask = [
        [px[x, y][3] > 0 and px[x, y][:3] in WING_LEVELS for x in range(FRAME_W)]
        for y in range(FRAME_H)
    ]
    blobs = sorted(components(mask, FRAME_W, FRAME_H), key=len, reverse=True)
    if not blobs or len(blobs[0]) < MIN_COMPONENT:
        sys.exit(f"frame {index}: no wing-sized component found")

    # ONE wing, the near one. The demon is drawn in 3/4, so its far wing is half behind
    # the body and masks out as a stunted fragment — 919 px against 1984 on frame 0, and
    # on the up-stroke it all but disappears. Taking the pair as authored gave a
    # character that looked like it was missing a wing every other beat.
    #
    # body_marks.gd mirrors this one about the body's centre line to make the pair, which
    # also means the wings are symmetric and need no flip when the player turns around.
    keep = set(blobs[0])
    out = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
    op = out.load()
    for x, y in keep:
        level = WING_LEVELS[px[x, y][:3]]
        op[x, y] = (level, level, level, 255)
    print(f"  frame {index}: near wing {len(keep)} px, discarded {len(blobs) - 1} "
          f"other blobs (largest {len(blobs[1]) if len(blobs) > 1 else 0})")
    return out


def main() -> None:
    demon = load_demon()
    if demon.size != (FRAME_W * 6, FRAME_H):
        sys.exit(f"demon-idle.png is {demon.size}, expected {(FRAME_W * 6, FRAME_H)}")

    wings = [extract(demon, i) for i in USE_FRAMES]

    # One canvas for every frame. Cropping each frame to its own bounds would be tighter
    # but would move the pivot per frame, which is precisely the jitter to avoid.
    box = [FRAME_W, FRAME_H, 0, 0]
    for w in wings:
        b = w.getbbox()
        if b is None:
            sys.exit("a wing frame came out empty — the palette or threshold is wrong")
        box = [min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3])]
    fw, fh = box[2] - box[0], box[3] - box[1]
    pivot = (PIVOT[0] - box[0], PIVOT[1] - box[1])
    print(f"  canvas {fw}x{fh}, pivot {pivot}")

    strip = Image.new("RGBA", (fw * len(wings), fh), (0, 0, 0, 0))
    for i, w in enumerate(wings):
        strip.paste(w.crop(tuple(box)), (i * fw, 0))
    os.makedirs(os.path.dirname(OUT_PNG), exist_ok=True)
    strip.save(OUT_PNG)
    print(f"  -> {os.path.relpath(OUT_PNG, ROOT)}  ({strip.size[0]}x{strip.size[1]})")

    # No SpriteFrames resource is written. body_marks.gd draws the strip itself in
    # _draw(), because the beat has to speed up in the air and slow on the ground off the
    # same _phase the tail already uses — an AnimatedSprite2D would mean a second node
    # and a speed_scale to keep in sync for nothing. The strip is a plain horizontal grid,
    # so the region maths below is all a consumer needs.
    print(f"\nbody_marks.gd expects:  WING_FRAME = Vector2({fw}, {fh})   "
          f"WING_PIVOT = Vector2({pivot[0]}, {pivot[1]})   frames = {len(wings)}")


if __name__ == "__main__":
    main()
