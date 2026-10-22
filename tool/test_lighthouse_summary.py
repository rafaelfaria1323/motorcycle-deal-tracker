"""Tests for tool/lighthouse_summary.py: python3 -m unittest discover -s tool -p 'test_*.py'"""

import unittest

from lighthouse_summary import summarize


def _report(**extra):
    report = {
        "categories": {
            "performance": {"score": 0.42},
            "accessibility": {
                "score": 0.9,
                "auditRefs": [
                    {"id": "button-name", "weight": 10},
                    {"id": "color-contrast", "weight": 7},
                    {"id": "not-applicable", "weight": 0},
                ],
            },
            "best-practices": {"score": 1},
        },
        "audits": {
            "first-contentful-paint": {"numericValue": 1234},
            "largest-contentful-paint": {"numericValue": 4560},
            "total-blocking-time": {"numericValue": 310.4},
            "cumulative-layout-shift": {"numericValue": 0.012},
            "total-byte-weight": {"numericValue": 3_450_000},
            "button-name": {"score": 0, "title": "Buttons have no name"},
            "color-contrast": {"score": 1, "title": "Contrast"},
            "not-applicable": {"score": 0, "title": "Ignored"},
        },
    }
    report.update(extra)
    return report


class LighthouseSummaryTest(unittest.TestCase):
    def test_scores_metrics_and_failed_accessibility(self):
        self.assertEqual(summarize(_report()), [
            "**Lighthouse (mobile):** Performance 42 · Accessibility 90 · Best practices 100",
            "First Contentful Paint 1.2 s · Largest Contentful Paint 4.6 s · "
            "Total Blocking Time 310 ms · Cumulative Layout Shift 0.01 · Download 3.5 MB",
            "Accessibility to fix: Buttons have no name",
        ])

    def test_largest_element_downloads_and_failed_best_practices(self):
        site = "https://pr-1.motorcycle-deal-tracker.pages.dev"
        report = _report()
        report["categories"]["best-practices"] = {
            "score": 0.77,
            "auditRefs": [{"id": "errors-in-console", "weight": 1}],
        }
        report["audits"].update({
            "errors-in-console": {"score": 0, "title": "Browser errors were logged"},
            "largest-contentful-paint-element": {"details": {"type": "list", "items": [
                {"type": "table", "items": [
                    {"node": {"type": "node", "snippet": '<img src="https://ireland.apollo.olxcdn.com/x">'}},
                ]},
            ]}},
            "network-requests": {"details": {"items": [
                {"url": f"{site}/main.dart.wasm", "transferSize": 1_500_000,
                 "resourceSize": 1_520_000},
                {"url": f"{site}/canvaskit/skwasm.wasm", "transferSize": 900_000,
                 "resourceSize": 2_700_000},
                {"url": "https://ireland.apollo.olxcdn.com/v1/files/abc/image?s=1",
                 "transferSize": 120_000, "resourceSize": 120_000},
                {"url": f"{site}/favicon.png", "transferSize": 5_000,
                 "resourceSize": 5_000},
                {"url": f"{site}/cached.js", "transferSize": 0},
            ]}},
        })
        lines = summarize(report)
        self.assertEqual(lines[2], "Largest element: `<img src=\"https://ireland.apollo.olxcdn.com/x\">`")
        self.assertEqual(lines[3], (
            "Biggest downloads: main.dart.wasm 1.5 MB (not compressed) · "
            "skwasm.wasm 900 KB (2.7 MB unpacked) · "
            "ireland.apollo.olxcdn.com/…/image 120 KB · favicon.png 5 KB"
        ))
        self.assertEqual(lines[4:], [
            "Accessibility to fix: Buttons have no name",
            "Best practices to fix: Browser errors were logged",
        ])

    def test_largest_element_from_the_lcp_insight(self):
        report = _report()
        report["audits"]["lcp-breakdown-insight"] = {"details": {"type": "list", "items": [
            {"type": "table", "items": [{"subpart": "ttfb"}]},
            {"type": "node", "nodeLabel": "flt-glass-pane", "snippet": "<flt-glass-pane>"},
        ]}}
        self.assertIn("Largest element: `<flt-glass-pane>`", summarize(report))

    def test_a_page_that_did_not_load(self):
        report = _report(runtimeError={"code": "NO_FCP", "message": "..."})
        self.assertEqual(summarize(report), [
            "**Lighthouse:** the page did not load (NO_FCP).",
        ])

    def test_many_failures_are_cut_short(self):
        report = _report()
        refs = report["categories"]["accessibility"]["auditRefs"]
        for i in range(7):
            refs.append({"id": f"a{i}", "weight": 1})
            report["audits"][f"a{i}"] = {"score": 0, "title": f"A{i}"}
        last = summarize(report)[-1]
        self.assertTrue(last.endswith("(+3)"), last)
        self.assertEqual(last.count(";"), 4)

    def test_missing_parts_are_left_out(self):
        self.assertEqual(
            summarize({"categories": {"performance": {"score": 0.5}}}),
            ["**Lighthouse (mobile):** Performance 50"],
        )


if __name__ == "__main__":
    unittest.main()
