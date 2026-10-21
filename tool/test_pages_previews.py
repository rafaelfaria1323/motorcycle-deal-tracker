"""Tests for tool/pages_previews.py: python3 -m unittest discover -s tool -p 'test_*.py'"""

import unittest

from pages_previews import to_delete


def deployment(id, branch, created, environment="preview"):
    return {"id": id, "environment": environment, "created_on": created,
            "deployment_trigger": {"metadata": {"branch": branch}}}


DEPLOYMENTS = [
    deployment("old", "pr-7", "2026-10-20T10:00:00Z"),
    deployment("new", "pr-7", "2026-10-20T12:00:00Z"),
    deployment("mid", "pr-7", "2026-10-20T11:00:00Z"),
    deployment("other", "pr-8", "2026-10-20T13:00:00Z"),
    deployment("prod", "main", "2026-10-20T14:00:00Z", environment="production"),
    # A production deployment named like a preview is still never touched.
    deployment("odd", "pr-7", "2026-10-20T15:00:00Z", environment="production"),
    {"id": "no-trigger", "environment": "preview"},
]


class ToDeleteTest(unittest.TestCase):
    def test_after_a_push_all_but_the_newest(self):
        self.assertEqual(to_delete(DEPLOYMENTS, "pr-7", keep_latest=True), ["mid", "old"])

    def test_when_closed_all_of_the_pr(self):
        self.assertEqual(to_delete(DEPLOYMENTS, "pr-7", keep_latest=False),
                         ["new", "mid", "old"])

    def test_other_prs_are_left_alone(self):
        self.assertEqual(to_delete(DEPLOYMENTS, "pr-8", keep_latest=True), [])
        self.assertEqual(to_delete(DEPLOYMENTS, "pr-9", keep_latest=False), [])

    def test_never_production_or_another_branch_name(self):
        for branch in ["main", "", None, "pr-", "pr-7x", "feature"]:
            with self.subTest(branch=branch):
                with self.assertRaises(ValueError):
                    to_delete(DEPLOYMENTS, branch, keep_latest=False)


if __name__ == "__main__":
    unittest.main()
