"""Tests for tool/mutation.py: python3 -m unittest discover -s tool -p 'test_*.py'"""

import contextlib
import io
import os
import tempfile
import unittest

from mutation import declared_names, summary, test_command, tests_using

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


DART = """\
import 'package:x/y.dart';

const maxItems = 3;
final class Fetcher {
  void get(String url) {}
  final RegExp pattern = RegExp('a');
}
sealed class Outcome {}
class const PlannedSearch(final String url);
extension type const Cents(int value) {}
enum Site { olx }
typedef Rows = List<int>;
List<String> cleanImages(List<String> raw) => raw;
Map<String, int> get counts => {};
T first<T>(List<T> values) => values.first;
int _hidden() => 1;
"""


class TestsUsingTest(unittest.TestCase):
    def test_top_level_public_names_only(self):
        self.assertEqual(
            declared_names(DART),
            {'maxItems', 'Fetcher', 'Outcome', 'PlannedSearch', 'Cents', 'Site',
             'Rows', 'cleanImages', 'counts', 'first'},
        )

    def test_the_test_files_naming_them(self):
        with tempfile.TemporaryDirectory() as root:
            os.makedirs(os.path.join(root, 'lib'))
            os.makedirs(os.path.join(root, 'test', 'deep'))
            files = {
                'lib/a.dart': 'class Fetcher {}\nint cleanImages() => 1;\n',
                'test/a_test.dart': 'Fetcher();',
                'test/deep/b_test.dart': 'cleanImages();',
                'test/c_test.dart': 'FetcherOther(); // not the same name',
                'test/helpers.dart': 'Fetcher();',
            }
            for name, text in files.items():
                with open(os.path.join(root, name), 'w', encoding='utf-8') as f:
                    f.write(text)
            self.assertEqual(
                tests_using(root, 'lib/a.dart'),
                ['test/a_test.dart', 'test/deep/b_test.dart'],
            )

    def test_commands(self):
        self.assertEqual(
            test_command('app', 'lib/x/y_text.dart'),
            'flutter test --no-pub test/y_text_test.dart',
        )
        command = test_command('collector', 'lib/src/fetch/robots.dart')
        self.assertTrue(command.startswith('dart test -r failures-only test/'))
        self.assertIn('test/fetch_test.dart', command.split())


if __name__ == '__main__':
    unittest.main()
