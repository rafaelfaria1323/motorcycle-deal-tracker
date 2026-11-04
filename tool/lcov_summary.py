"""Line coverage from an lcov file: a summary, the least covered files, and a
floor that fails the check when coverage drops below it.

    python3 tool/lcov_summary.py app/coverage/lcov.info --name app \\
        --only '_text\\.dart$|/domain/|/data/models/' --min 80

Several lcov files (one per CI shard) are merged line by line first.

--only keeps the files whose path matches the regular expression (the
logic worth a floor; widgets are tried on the phone). On GitHub Actions
the summary also goes to the run's summary page. Used by `make coverage`
and check.yml; tests: tool/test_lcov_summary.py.
"""

import argparse
import os
import re
import sys


def parse_lcov(*texts):
    """{path: (lines found, lines hit)} from one or more lcov texts. The
    texts of a suite run in shards are merged line by line: a file in two
    shards' reports counts each line once, hit when either shard hit it."""
    lines = {}  # path -> {line: hit}
    for text in texts:
        path = None
        for line in text.splitlines():
            line = line.strip()
            if line.startswith("SF:"):
                # Short paths in the report (lcov from `dart test` has absolute ones).
                path = os.path.relpath(line[3:]) if os.path.isabs(line[3:]) else line[3:]
                lines.setdefault(path, {})
            elif line.startswith("DA:") and path is not None:
                number, hits = line[3:].split(",")[:2]
                seen = lines[path]
                seen[number] = seen.get(number, False) or int(hits) > 0
            elif line == "end_of_record":
                path = None
    return {p: (len(v), sum(v.values())) for p, v in lines.items()}


def summarize(files, only=None):
    """(percent, found, hit, [(percent, path)] least covered first)."""
    if only:
        pattern = re.compile(only)
        files = {p: v for p, v in files.items() if pattern.search(p)}
    found = sum(f for f, _ in files.values())
    hit = sum(h for _, h in files.values())
    per_file = sorted((100.0 * h / f if f else 100.0, p) for p, (f, h) in files.items())
    return (100.0 * hit / found if found else 100.0), found, hit, per_file


def report(name, percent, found, hit, per_file, minimum, worst=5):
    lines = [f"### Coverage: {name} {percent:.1f}% ({hit}/{found} lines, floor {minimum:g}%)"]
    if per_file:
        lines.append("Least covered:")
        lines += [f"- {p:.0f}% {path}" for p, path in per_file[:worst]]
    return "\n".join(lines)


def main(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument("lcov", nargs="+", help="lcov files (a sharded run's, merged)")
    parser.add_argument("--name", default="coverage")
    parser.add_argument("--only")
    parser.add_argument("--min", type=float, default=0)
    args = parser.parse_args(argv)

    texts = []
    for path in args.lcov:
        with open(path) as f:
            texts.append(f.read())
    percent, found, hit, per_file = summarize(parse_lcov(*texts), args.only)
    text = report(args.name, percent, found, hit, per_file, args.min)
    print(text)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a") as f:
            f.write(text + "\n\n")
    if found == 0:
        print(f"::error::No lines measured for {args.name} (wrong --only or empty lcov)")
        return 1
    if percent < args.min:
        print(f"::error::{args.name} coverage {percent:.1f}% is below the floor of {args.min:g}%."
              " Add tests (or lower the floor in the Makefile with a reason).")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
