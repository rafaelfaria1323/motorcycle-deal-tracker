"""Keep local, production and check SDK selections aligned without network I/O."""

import json
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]


class SdkVersionsTest(unittest.TestCase):
    def test_pins_are_exact_and_match_package_minimums(self):
        flutter = json.loads((ROOT / ".fvmrc").read_text())["flutter"]
        dart = (ROOT / ".dart-version").read_text().strip()
        for version in (flutter, dart):
            self.assertRegex(version, r"^\d+\.\d+\.\d+$")
        for package in ("app", "collector"):
            manifest = (ROOT / package / "pubspec.yaml").read_text()
            self.assertIn(f"  sdk: ^{dart}\n", manifest)
            lockfile = (ROOT / package / "pubspec.lock").read_text()
            self.assertIn(f'  dart: ">={dart} <4.0.0"\n', lockfile)
        self.assertIn(
            f'  flutter: ">={flutter}"\n',
            (ROOT / "app/pubspec.yaml").read_text(),
        )
        self.assertIn(
            f'  flutter: ">={flutter}"\n',
            (ROOT / "app/pubspec.lock").read_text(),
        )

    def test_every_flutter_setup_reads_the_project_pin(self):
        setups = 0
        for path in (ROOT / ".github").rglob("*.yml"):
            text = path.read_text()
            for match in re.finditer(
                r"(?m)^( +)(- )?uses: subosito/flutter-action@[^\n]+", text
            ):
                setups += 1
                step_indent = len(match[1]) - (0 if match[2] else 2)
                remaining = text[match.end():]
                end = re.search(
                    rf"(?m)^ {{0,{step_indent}}}\S", remaining
                )
                step = remaining[:end.start()] if end else remaining
                with self.subTest(path=path, step=setups):
                    self.assertRegex(
                        step, r"(?m)^\s+flutter-version-file: \.fvmrc$"
                    )
                    self.assertNotRegex(step, r"(?m)^\s+flutter-version:")
        self.assertGreater(setups, 0)

    def test_flutter_pin_changes_trigger_app_builds(self):
        for workflow in ("deploy-web", "preview-web", "android-check"):
            text = (ROOT / ".github/workflows" / f"{workflow}.yml").read_text()
            paths = text.split("    paths:\n", 1)[1].split("\n\n", 1)[0]
            with self.subTest(workflow=workflow):
                self.assertIn("      - '.fvmrc'", paths)

    def test_standalone_setups_read_the_dart_pin(self):
        action = (ROOT / ".github/actions/collector/action.yml").read_text()
        self.assertIn('echo "version=$(cat .dart-version)"', action)
        self.assertIn("sdk: ${{ steps.dart.outputs.version }}", action)
        self.assertIn("problem-matcher: false", action)
        self.assertIn("dart pub get --enforce-lockfile", action)
        hook = (ROOT / ".claude/hooks/session-start.sh").read_text()
        self.assertIn("dart_version=$(cat .dart-version)", hook)
        self.assertIn("release/$dart_version/sdk/", hook)
        self.assertNotIn("release/latest/", hook)

    def test_collector_checks_reuse_production_setup_without_flutter(self):
        text = (ROOT / ".github/workflows/check.yml").read_text()
        job = text.split("  collector-db:\n", 1)[1].split("\n  check:", 1)[0]
        self.assertIn("uses: ./.github/actions/collector", job)
        self.assertIn("dart run bin/report_run.dart", job)
        self.assertNotIn("subosito/flutter-action", job)
        self.assertNotIn("  collector-setup:\n", text)
        self.assertIn("needs: [app, smoke, collector-db]", text)


if __name__ == "__main__":
    unittest.main()
