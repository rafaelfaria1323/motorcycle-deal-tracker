"""A Lighthouse JSON report (mobile, the default) as a few Markdown lines:
the category scores, the load metrics and the size of the download, the
page's largest element, the biggest downloads (and whether each came
compressed), then the accessibility and best-practice checks that failed.

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
MAX_DOWNLOADS = 6
# A file that arrives at least this share of its own size wasn't compressed
# (small files aren't worth flagging; photos and WOFF2 come compressed).
UNCOMPRESSED_SHARE = 0.95
UNCOMPRESSED_MIN_BYTES = 20_000
COMPRESSIBLE = (".wasm", ".js", ".mjs", ".json", ".css", ".html", ".ttf", ".otf")


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
    element = _largest_element(audits)
    if element:
        lines.append(f"Largest element: `{element}`")
    downloads = _biggest_downloads(audits)
    if downloads:
        lines.append("Biggest downloads: " + " · ".join(downloads))
    for key, label in (("accessibility", "Accessibility"), ("best-practices", "Best practices")):
        failed = _failed(categories.get(key, {}), audits)
        if failed:
            shown = "; ".join(failed[:MAX_FAILED])
            more = f" (+{len(failed) - MAX_FAILED})" if len(failed) > MAX_FAILED else ""
            lines.append(f"{label} to fix: {shown}{more}")
    return lines


def _failed(category, audits):
    """Titles of the category's scored checks that failed."""
    return [
        audits[ref["id"]]["title"]
        for ref in category.get("auditRefs", [])
        if ref.get("weight", 0) > 0
        and audits.get(ref["id"], {}).get("score") == 0
    ]


def _largest_element(audits):
    """The node Lighthouse counted as the largest paint, as a short label.
    Lighthouse 13 has it in the LCP insight; older ones in its own audit."""
    for key in ("lcp-breakdown-insight", "largest-contentful-paint-element"):
        node = _first_node(audits.get(key, {}).get("details"))
        if node:
            label = node.get("snippet") or node.get("nodeLabel") or ""
            return label[:120].replace("`", "'")
    return None


def _first_node(value):
    """The first {"type": "node"} anywhere in an audit's details."""
    if isinstance(value, dict):
        if value.get("type") == "node":
            return value
        values = value.values()
    elif isinstance(value, list):
        values = value
    else:
        return None
    for inner in values:
        node = _first_node(inner)
        if node:
            return node
    return None


def _name(url):
    """A request's file name; with its host when it isn't the page's own."""
    rest = url.split("://", 1)[-1].split("?", 1)[0]
    host, _, path = rest.partition("/")
    name = path.rstrip("/").rsplit("/", 1)[-1] or host
    return name if host.endswith(".pages.dev") else f"{host}/…/{name}"


def _biggest_downloads(audits):
    items = audits.get("network-requests", {}).get("details", {}).get("items", [])
    items = [i for i in items if i.get("transferSize")]
    items.sort(key=lambda i: i["transferSize"], reverse=True)
    shown = []
    for item in items[:MAX_DOWNLOADS]:
        sent = item["transferSize"]
        name = _name(item.get("url", ""))
        text = f"{name} {_kb(sent)}"
        size = item.get("resourceSize") or 0
        if (name.endswith(COMPRESSIBLE) and size >= UNCOMPRESSED_MIN_BYTES
                and sent >= size * UNCOMPRESSED_SHARE):
            text += " (not compressed)"
        elif size > sent:
            text += f" ({_kb(size)} unpacked)"
        shown.append(text)
    return shown


def _kb(value):
    if value >= 1_000_000:
        return f"{value / 1_000_000:.1f} MB"
    return f"{value / 1000:.0f} KB"


def main(argv):
    with open(argv[1], encoding="utf-8") as f:
        report = json.load(f)
    print("\n".join(summarize(report)))


if __name__ == "__main__":
    main(sys.argv)
