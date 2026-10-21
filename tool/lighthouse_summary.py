"""A Lighthouse JSON report (mobile, the default) as a few Markdown lines:
the category scores, the load metrics and the size of the download, then
the accessibility checks that failed.

    python3 -I tool/lighthouse_summary.py report.json

Used by preview-web.yml on every PR preview (run summary and the preview
comment); report only, nothing fails on a score. Tests:
tool/test_lighthouse_summary.py.
"""

import json
import sys

CATEGORIES = [
    ("performance", "Performance"),
    ("accessibility", "Accessibility"),
    ("best-practices", "Best practices"),
]
# (audit id, label, unit): ms shown as seconds, bytes as MB.
METRICS = [
    ("first-contentful-paint", "First Contentful Paint", "ms"),
    ("largest-contentful-paint", "Largest Contentful Paint", "ms"),
    ("total-blocking-time", "Total Blocking Time", "ms-raw"),
    ("cumulative-layout-shift", "Cumulative Layout Shift", "unitless"),
    ("total-byte-weight", "Download", "bytes"),
]
MAX_FAILED = 5


def _value(value, unit):
    if unit == "ms":
        return f"{value / 1000:.1f} s"
    if unit == "ms-raw":
        return f"{value:.0f} ms"
    if unit == "bytes":
        return f"{value / 1_000_000:.1f} MB"
    return f"{value:.2f}"


def summarize(report):
    """Markdown lines for one report."""
    error = report.get("runtimeError")
    if error:
        return [f"**Lighthouse:** the page did not load ({error.get('code', 'error')})."]
    categories = report.get("categories", {})
    scores = []
    for key, label in CATEGORIES:
        score = categories.get(key, {}).get("score")
        if score is not None:
            scores.append(f"{label} {round(score * 100)}")
    lines = ["**Lighthouse (mobile):** " + " · ".join(scores)]
    audits = report.get("audits", {})
    metrics = []
    for key, label, unit in METRICS:
        value = audits.get(key, {}).get("numericValue")
        if value is not None:
            metrics.append(f"{label} {_value(value, unit)}")
    if metrics:
        lines.append(" · ".join(metrics))
    failed = [
        audits[ref["id"]]["title"]
        for ref in categories.get("accessibility", {}).get("auditRefs", [])
        if ref.get("weight", 0) > 0
        and audits.get(ref["id"], {}).get("score") == 0
    ]
    if failed:
        shown = "; ".join(failed[:MAX_FAILED])
        more = f" (+{len(failed) - MAX_FAILED})" if len(failed) > MAX_FAILED else ""
        lines.append(f"Accessibility to fix: {shown}{more}")
    return lines


def main(argv):
    with open(argv[1], encoding="utf-8") as f:
        report = json.load(f)
    print("\n".join(summarize(report)))


if __name__ == "__main__":
    main(sys.argv)
