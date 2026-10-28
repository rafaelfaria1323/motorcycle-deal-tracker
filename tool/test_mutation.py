"""Tests for tool/mutation.py: python3 -m unittest discover -s tool -p 'test_*.py'"""

import contextlib
import io
import os
import tempfile
import unittest

from mutation import summary

REPORT = """\
| Key | Value |
|---|---|
| Mutations | {total} |
| Undetected | {left} |
| Timeouts | 0 |
"""

XML = """<?xml version="1.0"?>
<report><file><mutation line="3"><original>&lt;</original>\
<modified>&lt;=</modified></mutation></file></report>
"""


class SummaryTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.dir.cleanup)
        report = os.path.join(self.dir.name, 'collector-lib-a-dart')
        os.makedirs(report)
        files = {
            'target.txt': 'collector/lib/a.dart\n',
            'mutation-test-report.md': REPORT.format(total=10, left=1),
            'mutation-test-report.xml': XML,
        }
        for name, text in files.items():
            with open(os.path.join(report, name), 'w', encoding='utf-8') as f:
                f.write(text)

    def run_summary(self, *args):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            summary([*args, self.dir.name])
        return out.getvalue()

    def test_score_and_survivors(self):
        text = self.run_summary()
        self.assertIn('**Score: 90 %** (9 of 10', text)
        self.assertIn('- `collector/lib/a.dart:3`: `<` → `<=`', text)

    def test_floor_met_passes(self):
        self.assertIn('Score: 90 %', self.run_summary('--floor', '90'))

    def test_floor_missed_fails_after_the_summary(self):
        with self.assertRaises(SystemExit) as raised:
            self.run_summary('--floor', '90.5')
        self.assertIn('below the floor of 90.5 %', str(raised.exception))


if __name__ == '__main__':
    unittest.main()
