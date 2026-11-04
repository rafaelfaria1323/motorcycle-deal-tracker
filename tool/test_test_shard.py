"""Tests for tool/test_shard.py: python3 -m unittest discover -s tool -p 'test_*.py'"""

import io
import json
import os
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout

from test_shard import (file_costs, main, plan, read_times, report_times,
                        run_times, shard_count, shards, test_files, weights)


def _report(*events):
    """One JSON report's lines from (type, ms, fields) tuples."""
    return [json.dumps({"type": kind, "time": ms, **fields}) for kind, ms, fields in events]


def _package(folder, files):
    """A package under folder with test files {relative name: bytes}."""
    for name, size in files.items():
        path = os.path.join(folder, name)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            f.write("x" * size)
    return folder


class ShardTest(unittest.TestCase):
    def test_every_file_in_exactly_one_shard(self):
        sizes = {f"test/{i}_test.dart": (i * 37) % 11 + 1 for i in range(25)}
        for total in (1, 2, 3, 4):
            groups = shards(sizes, total)
            self.assertEqual(len(groups), total)
            together = [f for g in groups for f in g]
            self.assertEqual(sorted(together), sorted(sizes))

    def test_biggest_files_go_to_the_lightest_shard(self):
        sizes = {"a": 10, "b": 6, "c": 5, "d": 1}
        # a -> 0 (10); b -> 1 (6); c -> 1 (11); d -> 0 (11).
        self.assertEqual(shards(sizes, 2), [["a", "d"], ["b", "c"]])

    def test_one_shard_is_every_file(self):
        self.assertEqual(shards({"b": 1, "a": 2}, 1), [["a", "b"]])

    def test_more_shards_than_files_leaves_some_empty(self):
        self.assertEqual(shards({"a": 1}, 2), [["a"], []])

    def test_files_found_under_test_relative_to_the_package(self):
        with tempfile.TemporaryDirectory() as package:
            os.makedirs(os.path.join(package, "test", "helpers"))
            for name in ("test/b_test.dart", "test/helpers/a_test.dart",
                         "test/helpers/fixture.dart", "test/notes.md"):
                with open(os.path.join(package, name), "w") as f:
                    f.write("x")
            self.assertEqual(test_files(package),
                             ["test/b_test.dart", "test/helpers/a_test.dart"])

    def test_an_empty_shard_is_an_error_not_every_test(self):
        with tempfile.TemporaryDirectory() as package:
            os.makedirs(os.path.join(package, "test"))
            with open(os.path.join(package, "test", "a_test.dart"), "w") as f:
                f.write("x")
            self.assertEqual(main([package, "2", "0"]), 0)
            self.assertEqual(main([package, "2", "1"]), 1)

    def test_a_shard_that_does_not_exist_is_a_usage_error(self):
        with redirect_stderr(io.StringIO()):
            self.assertEqual(main(["app", "2", "2"]), 64)
            self.assertEqual(main(["app", "0", "0"]), 64)
            self.assertEqual(main(["app", "two", "0"]), 64)
            self.assertEqual(main(["app"]), 64)
            self.assertEqual(main(["plan"]), 64)
            self.assertEqual(main(["times"]), 64)


class TimesTest(unittest.TestCase):
    def test_a_report_gives_each_file_from_its_first_test_to_its_last(self):
        lines = _report(
            ("suite", 0, {"suite": {"id": 1, "path": "/w/repo/app/test/a_test.dart"}}),
            ("suite", 0, {"suite": {"id": 2, "path": "test/b_test.dart"}}),
            ("suite", 0, {"suite": {"id": 3, "path": "/elsewhere/c_test.dart"}}),
            ("testStart", 1000, {"test": {"id": 10, "suiteID": 1}}),
            ("testDone", 4000, {"testID": 10}),
            ("testStart", 5000, {"test": {"id": 11, "suiteID": 2}}),
            ("testDone", 6000, {"testID": 11}),
            ("testStart", 6000, {"test": {"id": 12, "suiteID": 2}}),
            ("testDone", 7500, {"testID": 12}),
            ("done", 10000, {}),
        ) + ["not json", "[1]", json.dumps({"type": "suite"})]
        spans, wall = report_times(lines, "app")
        self.assertEqual(spans, {"test/a_test.dart": 3.0, "test/b_test.dart": 2.5})
        self.assertEqual(wall, 10.0)

    def test_costs_share_the_time_between_files_and_add_up_to_the_wall(self):
        costs = file_costs({"a": 3.0, "b": 1.0}, 10.0)
        self.assertEqual(costs, {"a": 6.0, "b": 4.0})
        # Overlapping files (spans above the wall) are scaled down.
        costs = file_costs({"a": 6.0, "b": 2.0}, 4.0)
        self.assertAlmostEqual(costs["a"], 3.0)
        self.assertAlmostEqual(costs["b"], 1.0)
        self.assertEqual(file_costs({}, 5.0), {})

    def test_a_runs_times_take_each_shards_report(self):
        with tempfile.TemporaryDirectory() as folder:
            for shard, (name, ms) in enumerate((("a", 2000), ("b", 4000))):
                os.makedirs(os.path.join(folder, f"coverage-collector-{shard}"))
                with open(os.path.join(folder, f"coverage-collector-{shard}", "tests.jsonl"), "w") as f:
                    f.write("\n".join(_report(
                        ("suite", 0, {"suite": {"id": 1, "path": f"test/{name}_test.dart"}}),
                        ("testStart", 0, {"test": {"id": 1, "suiteID": 1}}),
                        ("testDone", ms, {"testID": 1}),
                    )))
            self.assertEqual(run_times(folder), {"collector": {
                "test/a_test.dart": 2.0, "test/b_test.dart": 4.0}})

    def test_only_sane_times_are_read(self):
        with tempfile.TemporaryDirectory() as folder:
            path = os.path.join(folder, "times.json")
            with open(path, "w") as f:
                json.dump({"app": {"test/a_test.dart": 3, "test/../x_test.dart; rm": 1,
                                   "test/b_test.dart": 99999, "test/c.dart": 1},
                           "collector": {"test/z_test.dart": 1}}, f)
            self.assertEqual(read_times(path, "app"), {"test/a_test.dart": 3.0})
            with open(path, "w") as f:
                f.write("not json")
            self.assertEqual(read_times(path, "app"), {})
            with open(path, "w") as f:
                json.dump({"app": {"test/a_test.dart": "slow"}}, f)
            self.assertEqual(read_times(path, "app"), {})
        self.assertEqual(read_times(None, "app"), {})
        self.assertEqual(read_times("/does/not/exist.json", "app"), {})


class PlanTest(unittest.TestCase):
    def test_a_new_file_weighs_the_median_and_gone_files_are_dropped(self):
        with tempfile.TemporaryDirectory() as folder:
            package = _package(folder, {"test/a_test.dart": 1, "test/b_test.dart": 1,
                                        "test/c_test.dart": 1, "test/new_test.dart": 1})
            times = os.path.join(folder, "times.json")
            with open(times, "w") as f:
                json.dump({os.path.basename(folder): {"test/a_test.dart": 10, "test/b_test.dart": 20,
                                   "test/c_test.dart": 60, "test/gone_test.dart": 500}}, f)
            found, seconds = weights(package, times)
            self.assertEqual(found["test/new_test.dart"], 20)
            self.assertNotIn("test/gone_test.dart", found)
            self.assertEqual(seconds, 110)

    def test_without_times_files_weigh_their_bytes(self):
        with tempfile.TemporaryDirectory() as folder:
            package = _package(folder, {"test/a_test.dart": 2000, "test/b_test.dart": 1000})
            found, seconds = weights(package)
            self.assertEqual(found, {"test/a_test.dart": 2000, "test/b_test.dart": 1000})
            self.assertAlmostEqual(seconds, 3 * 0.3)

    def test_enough_shards_for_the_target_within_the_limits(self):
        self.assertEqual(shard_count(0, 5), 1)
        self.assertEqual(shard_count(40, 5), 1)
        self.assertEqual(shard_count(41, 5), 2)
        self.assertEqual(shard_count(130, 5), 4)
        self.assertEqual(shard_count(130, 2), 2)
        self.assertEqual(shard_count(10000, 100), 8)

    def test_the_plan_is_every_file_once_in_even_shards(self):
        with tempfile.TemporaryDirectory() as folder:
            names = [f"test/{i}_test.dart" for i in range(6)]
            package = _package(folder, {n: 1 for n in names})
            times = os.path.join(folder, "times.json")
            with open(times, "w") as f:
                json.dump({os.path.basename(folder): dict(zip(names, (30, 30, 20, 20, 10, 10)))}, f)
            matrix = plan(package, times)
            self.assertEqual([m["shard"] for m in matrix], [0, 1, 2])
            together = sorted(f for m in matrix for f in m["files"].split())
            self.assertEqual(together, names)
            out = io.StringIO()
            with redirect_stdout(out):
                self.assertEqual(main(["plan", package, times]), 0)
            self.assertEqual(json.loads(out.getvalue()), matrix)

    def test_a_plan_without_tests_fails(self):
        with tempfile.TemporaryDirectory() as folder, redirect_stderr(io.StringIO()):
            self.assertEqual(main(["plan", folder]), 1)


if __name__ == "__main__":
    unittest.main()
