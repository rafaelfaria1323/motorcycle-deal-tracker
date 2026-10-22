"""Checks that the bundled fonts can draw every character the app writes.

A character missing from the fonts (Barlow, Latin subset) still shows, but
on the web Flutter's engine first downloads a Google font that has it,
on the phone's slow first load (the arrows cost 63 KB that way). This
reads the non-ASCII characters of the app's code (comments left out) and
the characters each font maps (its cmap, format 4), and lists what a font
lacks. Missing arrows can be drawn with tool/font_arrows.py; anything else
needs a font with it, or other wording.

It also keeps the fonts small, since the web app downloads every one of
them before it draws: no TrueType hinting (it only helps low-resolution
screens; strip it with `pyftsubset FONT --unicodes='*' --glyphs='*'
--layout-features='*' --name-IDs='*' --notdef-outline --no-hinting`), and
no font file that app/pubspec.yaml doesn't declare.

    python3 tool/font_coverage.py    (from the repository root)

Tested by tool/test_font_coverage.py, which also runs it on the app.
"""

import pathlib
import re
import struct
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
COMMENT = re.compile(r"^\s*//")


# TrueType hinting: the instructions' programs and their control values.
HINTING_TABLES = {b"fpgm", b"prep", b"cvt "}


def font_tables(data):
    """{tag: offset} of a TrueType font's tables."""
    tables = struct.unpack_from(">H", data, 4)[0]
    found = {}
    for i in range(tables):
        tag, _, offset, _ = struct.unpack_from(">4sIII", data, 12 + 16 * i)
        found[tag] = offset
    return found


def font_characters(data):
    """The code points a TrueType font maps (its Unicode format 4 cmap)."""
    cmap = font_tables(data).get(b"cmap")
    if cmap is None:
        raise ValueError("no cmap table")
    count = struct.unpack_from(">H", data, cmap + 2)[0]
    for i in range(count):
        platform, encoding, offset = struct.unpack_from(">HHI", data, cmap + 4 + 8 * i)
        start = cmap + offset
        if (platform, encoding) in ((3, 1), (0, 3)) and struct.unpack_from(">H", data, start)[0] == 4:
            return _format4(data, start)
    raise ValueError("no Unicode format 4 cmap")


def _format4(data, start):
    segments = struct.unpack_from(">H", data, start + 6)[0] // 2
    ends = struct.unpack_from(f">{segments}H", data, start + 14)
    starts = struct.unpack_from(f">{segments}H", data, start + 16 + 2 * segments)
    deltas = struct.unpack_from(f">{segments}h", data, start + 16 + 4 * segments)
    ranges_at = start + 16 + 6 * segments
    ranges = struct.unpack_from(f">{segments}H", data, ranges_at)
    found = set()
    for i in range(segments):
        for code in range(starts[i], ends[i] + 1):
            if code == 0xFFFF:
                continue
            if ranges[i] == 0:
                glyph = (code + deltas[i]) & 0xFFFF
            else:
                at = ranges_at + 2 * i + ranges[i] + 2 * (code - starts[i])
                glyph = struct.unpack_from(">H", data, at)[0]
                glyph = (glyph + deltas[i]) & 0xFFFF if glyph else 0
            if glyph:
                found.add(code)
    return found


def written_characters(sources):
    """{character: first file that writes it} for the non-ASCII characters
    outside comments."""
    seen = {}
    for path in sources:
        for line in path.read_text(encoding="utf-8").splitlines():
            if COMMENT.match(line):
                continue
            for char in line:
                if ord(char) > 0x7E:
                    seen.setdefault(char, path)
    return seen


def missing(fonts, sources):
    """Lines naming each character a font lacks and where it is written."""
    written = written_characters(sources)
    lines = []
    for font in fonts:
        mapped = font_characters(font.read_bytes())
        for char, path in sorted(written.items()):
            if ord(char) not in mapped:
                lines.append(f"{font.name} lacks U+{ord(char):04X} {char!r} ({path})")
    return lines


def too_big(fonts, pubspec):
    """Lines naming each font with hinting or not declared in the pubspec."""
    lines = []
    for font in fonts:
        hinting = HINTING_TABLES & set(font_tables(font.read_bytes()))
        if hinting:
            tags = ", ".join(sorted(tag.decode().strip() for tag in hinting))
            lines.append(f"{font.name} has hinting ({tags})")
        if f"assets/fonts/{font.name}" not in pubspec:
            lines.append(f"{font.name} is not in app/pubspec.yaml")
    return lines


def main():
    fonts = sorted((ROOT / "app/assets/fonts").glob("*.ttf"))
    sources = sorted((ROOT / "app/lib").rglob("*.dart"))
    pubspec = (ROOT / "app/pubspec.yaml").read_text(encoding="utf-8")
    problems = missing(fonts, sources) + too_big(fonts, pubspec)
    print("\n".join(problems) or f"{len(fonts)} fonts draw every character the app writes.")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
