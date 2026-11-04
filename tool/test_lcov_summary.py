"""Tests for tool/lcov_summary.py: python3 -m unittest discover -s tool -p 'test_*.py'"""

import unittest

from lcov_summary import parse_lcov, summarize

LCOV = """\
SF:lib/a_text.dart
DA:1,3
DA:2,0
DA:3,1
end_of_record
SF:lib/widgets/b.dart
DA:1,0
DA:2,0
end_of_record
SF:lib/domain/c.dart
DA:1,1
end_of_record
"""


class CoverageTest(unittest.TestCase):
    def test_parse_counts_lines_found_and_hit(self):
        self.assertEqual(parse_lcov(LCOV), {
            "lib/a_text.dart": (3, 2),
            "lib/widgets/b.dart": (2, 0),
            "lib/domain/c.dart": (1, 1),
        })

    def test_shards_are_merged_line_by_line(self):
        first = "SF:lib/a_text.dart\nDA:1,1\nDA:2,0\nend_of_record\n"
        second = ("SF:lib/a_text.dart\nDA:1,0\nDA:2,4\nDA:3,0\nend_of_record\n"
                  "SF:lib/domain/c.dart\nDA:1,1\nend_of_record\n")
        self.assertEqual(parse_lcov(first, second), {
            "lib/a_text.dart": (3, 2),
            "lib/domain/c.dart": (1, 1),
        })

    def test_a_line_twice_in_one_report_counts_once(self):
        text = "SF:lib/a.dart\nDA:1,0\nDA:1,2\nend_of_record\n"
        self.assertEqual(parse_lcov(text), {"lib/a.dart": (1, 1)})

    def test_summary_of_everything_least_covered_first(self):
        percent, found, hit, per_file = summarize(parse_lcov(LCOV))
        self.assertEqual((found, hit), (6, 3))
        self.assertAlmostEqual(percent, 50.0)
        self.assertEqual(per_file[0][1], "lib/widgets/b.dart")

    def test_only_keeps_matching_files(self):
        percent, found, hit, _ = summarize(parse_lcov(LCOV), r"_text\.dart$|/domain/")
        self.assertEqual((found, hit), (4, 3))
        self.assertAlmostEqual(percent, 75.0)

    def test_nothing_measured(self):
        percent, found, _, per_file = summarize(parse_lcov(LCOV), "nothing")
        self.assertEqual((found, per_file), (0, []))
        self.assertEqual(percent, 100.0)


if __name__ == "__main__":
    unittest.main()
