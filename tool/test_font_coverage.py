"""Tests for tool/font_coverage.py: python3 -m unittest discover -s tool -p 'test_*.py'"""

import pathlib
import tempfile
import unittest

from font_coverage import ROOT, font_characters, main, missing, written_characters

FONT = ROOT / "app/assets/fonts/Barlow-Regular.ttf"


class FontCoverageTest(unittest.TestCase):
    def test_reads_the_font_map(self):
        characters = font_characters(FONT.read_bytes())
        for char in "Aé€·−›↓→":
            self.assertIn(ord(char), characters, char)
        self.assertNotIn(ord("★"), characters)

    def test_lists_what_a_font_lacks_outside_comments(self):
        with tempfile.TemporaryDirectory() as folder:
            source = pathlib.Path(folder, "a.dart")
            source.write_text(
                "/// ★ in a comment\n  // ✓ too\nconst a = 'Preço ↓ 5 € ★';\n",
                encoding="utf-8",
            )
            self.assertEqual(set(written_characters([source])), {"ç", "↓", "€", "★"})
            self.assertEqual(missing([FONT], [source]), [
                f"Barlow-Regular.ttf lacks U+2605 '★' ({source})",
            ])

    def test_the_app_writes_nothing_the_fonts_lack(self):
        self.assertEqual(main(), 0)


if __name__ == "__main__":
    unittest.main()
