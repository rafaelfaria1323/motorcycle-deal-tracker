"""Draws the arrows the app writes (← ↑ → ↓) into the bundled Barlow fonts.

Barlow has no arrows, so Flutter's web engine downloaded a Google font
just to draw "↓ 300 €" on the cards and "7 000 € → 6 500 €" in the alerts.
Each arrow is a shaft with a solid head, as thick as the font's own minus
sign and on its axis, so it matches every weight. Fonts that already have
an arrow are left as they are, so running it again changes nothing.

    pip install fonttools
    python3 tool/font_arrows.py app/assets/fonts/*.ttf

Run once by hand; the fonts it writes are committed. The guard that every
character the app writes is in the fonts is tool/font_coverage.py.
"""

import sys

from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont

ARROWS = {0x2190: "left", 0x2191: "up", 0x2192: "right", 0x2193: "down"}
# The horizontal arrow's length (times the minus sign's), the head's length
# (share of that) and its half-height (share of the head's length).
LENGTH = 1.35
HEAD_LENGTH = 0.36
HEAD_HALF = 0.8


def _bounds(font, char):
    glyphs = font.getGlyphSet()
    pen = BoundsPen(glyphs)
    glyphs[font.getBestCmap()[ord(char)]].draw(pen)
    return pen.bounds


def _right_arrow(length, head, thickness, centre):
    """The points of → from x 0 to `length` around y `centre`, clockwise."""
    half = round(head * HEAD_HALF)
    stem = thickness / 2
    return [
        (0, centre - stem), (0, centre + stem), (length - head, centre + stem),
        (length - head, centre + half), (length, centre),
        (length - head, centre - half), (length - head, centre - stem),
    ]


def _draw(points):
    pen = TTGlyphPen(None)
    pen.moveTo(points[0])
    for point in points[1:]:
        pen.lineTo(point)
    pen.closePath()
    return pen.glyph()


def add_arrows(font):
    """Adds the arrows the font lacks; returns how many it added."""
    cmap = font.getBestCmap()
    missing = [code for code in ARROWS if code not in cmap]
    if not missing:
        return 0
    x_min, y_min, x_max, y_max = _bounds(font, "−")
    side = x_min
    length = round((x_max - x_min) * LENGTH)
    head = round(length * HEAD_LENGTH)
    thickness = y_max - y_min
    axis = (y_min + y_max) / 2
    cap = font["OS/2"].sCapHeight
    right = _right_arrow(length, head, thickness, axis)
    half = max(y for _, y in right) - axis
    # Up: the same arrow turned to stand on the baseline, as tall as a
    # capital, with the same head, in a box as wide as the head plus the
    # minus's side bearings.
    up_length = cap
    up = _right_arrow(up_length, head, thickness, 0)
    width = round(2 * half + 2 * side)
    shapes = {
        "right": ([(x + side, y) for x, y in right], length + 2 * side),
        "left": ([(length - x + side, y) for x, y in reversed(right)], length + 2 * side),
        "up": ([(width / 2 - y, x) for x, y in up], width),
        "down": ([(width / 2 + y, up_length - x) for x, y in up], width),
    }
    order = font.getGlyphOrder()
    for code in missing:
        name = f"uni{code:04X}"
        points, advance = shapes[ARROWS[code]]
        glyph = _draw([(round(x), round(y)) for x, y in points])
        order.append(name)
        font["glyf"][name] = glyph
        glyph.recalcBounds(font["glyf"])
        font["hmtx"][name] = (round(advance), glyph.xMin)
        for table in font["cmap"].tables:
            if table.isUnicode():
                table.cmap[code] = name
    font.setGlyphOrder(order)
    return len(missing)


def main(paths):
    for path in paths:
        font = TTFont(path)
        added = add_arrows(font)
        if added:
            font.save(path)
        print(f"{path}: {added} arrows added")


if __name__ == "__main__":
    main(sys.argv[1:])
