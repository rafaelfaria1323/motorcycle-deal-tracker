"""Tests for tool/changed_areas.py: python3 -m unittest discover -s tool -p 'test_*.py'"""

import unittest

from changed_areas import needed

NONE = {"app": False, "collector": False, "db": False}
ALL = {"app": True, "collector": True, "db": True}


class NeededTest(unittest.TestCase):
    def test_documentation_needs_nothing(self):
        self.assertEqual(needed([
            "CLAUDE.md", "README.md", "app/README.md", "collector/README.md",
            "docs/roadmap.status.md", "docs/hosting.md", "LICENSE",
            ".claude/settings.json", ".claude/skills/x/SKILL.md", ""]), NONE)

    def test_nothing_changed_needs_nothing(self):
        self.assertEqual(needed([]), NONE)

    def test_the_app_skips_the_collectors_tests(self):
        self.assertEqual(needed(["app/lib/main.dart", "docs/roadmap.status.md"]),
                         {"app": True, "collector": False, "db": True})
        self.assertEqual(needed([".fvmrc"]),
                         {"app": True, "collector": False, "db": True})

    def test_the_collector_skips_flutter(self):
        for path in ("collector/lib/x.dart", ".dart-version",
                     ".github/actions/collector/action.yml",
                     "supabase/migrations/20261117000000_x.sql"):
            self.assertEqual(needed([path]),
                             {"app": False, "collector": True, "db": True}, path)

    def test_database_tools_and_workflows_need_only_collector_db(self):
        for path in ("supabase/tests/x_test.sql", "supabase/lint_allow.txt",
                     "tool/tax_tables.py", "tool/backup.sh", ".squawk.toml",
                     ".github/workflows/preview-web.yml", ".github/dependabot.yml",
                     ".claude/hooks/session-start.sh"):
            self.assertEqual(needed([path]),
                             {"app": False, "collector": False, "db": True}, path)

    def test_the_schema_snapshot_is_read_by_both_suites(self):
        self.assertEqual(needed(["supabase/schema.sql"]), ALL)

    def test_what_drives_the_check_needs_everything(self):
        for path in ("Makefile", ".github/workflows/check.yml",
                     "tool/test_shard.py", "tool/lcov_summary.py"):
            self.assertEqual(needed([path]), ALL, path)

    def test_an_unknown_file_needs_everything(self):
        self.assertEqual(needed(["something/new.txt"]), ALL)
        self.assertEqual(needed([".jscpd.json"]), ALL)

    def test_areas_add_up(self):
        self.assertEqual(needed(["app/lib/a.dart", "collector/lib/b.dart"]), ALL)


if __name__ == "__main__":
    unittest.main()
