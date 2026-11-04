"""Tests for tool/test_shard.py: python3 -m unittest discover -s tool -p 'test_*.py'"""

import os
import tempfile
import unittest

from test_shard import main, shards, test_files


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
        self.assertEqual(main(["app", "2", "2"]), 64)
        self.assertEqual(main(["app", "0", "0"]), 64)
        self.assertEqual(main(["app"]), 64)


if __name__ == "__main__":
    unittest.main()
