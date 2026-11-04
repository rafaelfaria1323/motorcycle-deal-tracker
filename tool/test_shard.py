"""How check.yml splits each suite's tests over parallel jobs: how many
jobs, and which `*_test.dart` files (under the package's test/) each
runs, relative to the package (`test/x_test.dart`) for `flutter test` or
`dart test`.

    python3 tool/test_shard.py plan app [times.json]   # check.yml's matrix
    python3 tool/test_shard.py app 2 0 [times.json]    # one shard's files
    python3 tool/test_shard.py times coverage          # times of a run

Split by file, not with the runners' --total-shards (which splits the
test cases of every file, so each shard would still compile every file:
most of a Flutter test run). Each file weighs what it took in the last
run (`times`: each shard's JSON report, from loading the file to its
last test, plus its share of the time between files, so a shard's files
add up to its time), a file without a time the median of the others;
with no times at all (the first run, or the artifact gone) its bytes at
the suite's measured rate. The heaviest files go first, each to the
lightest shard so far (ties by name), so the same times give the same
split. The number of shards: enough for each to take about
TARGET_SECONDS, at most MAX_SHARDS and never more than there are files
(so none is empty: a runner given no file would run them all). Used by
the Makefile's app-test-coverage / collector-test-coverage and
check.yml; tests: tool/test_test_shard.py.
"""

import glob
import json
import math
import os
import re
import statistics
import sys

# Each shard's tests should take about this long. check.yml's other
# jobs (analysis, the smoke, the database) take about 90 s, a test job's
# setup about 20 s: shards of 40 s never make the check wait longer, and
# more shards would only cost minutes.
TARGET_SECONDS = 40
# Never more jobs than this per suite, whatever the tests grow to.
MAX_SHARDS = 8
# Without times: seconds of a CI test run per KB of test files (measured
# 2026-11-04: app 126 s for 470 KB, collector 96 s for 313 KB).
SECONDS_PER_KB = {"app": 0.27, "collector": 0.31}
DEFAULT_SECONDS_PER_KB = 0.3
PACKAGES = tuple(SECONDS_PER_KB)


def test_files(package):
    """Every `*_test.dart` under package/test, relative to package, sorted."""
    root = os.path.join(package, "test")
    found = []
    for folder, _, names in os.walk(root):
        for name in names:
            if name.endswith("_test.dart"):
                found.append(os.path.relpath(os.path.join(folder, name), package))
    return sorted(found)


def shards(weights, total):
    """[[file, ...] per shard] from {file: weight}: heaviest first, each to
    the lightest shard so far (the lowest index on a tie); each sorted."""
    groups = [[] for _ in range(total)]
    loads = [0] * total
    for name in sorted(weights, key=lambda n: (-weights[n], n)):
        lightest = min(range(total), key=lambda i: (loads[i], i))
        groups[lightest].append(name)
        loads[lightest] += weights[name]
    return [sorted(g) for g in groups]


def _relative(path, package):
    """`test/...` for a report's suite path, absolute (flutter) or not."""
    if path.startswith("test/"):
        return path
    marker = f"/{package}/test/"
    if marker in path:
        return "test/" + path.rsplit(marker, 1)[1]
    return None


def report_times(lines, package):
    """({file: seconds}, wall seconds) from one JSON test report: each
    file from its first test (the loading) to its last."""
    paths, first, last, wall = {}, {}, {}, 0.0
    test_suite = {}
    for line in lines:
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if not isinstance(event, dict):
            continue
        kind, at = event.get("type"), event.get("time")
        if not isinstance(at, (int, float)):
            continue
        wall = max(wall, at / 1000)
        if kind == "suite":
            suite = event.get("suite") or {}
            path = _relative(str(suite.get("path", "")), package)
            if path:
                paths[suite.get("id")] = path
        elif kind == "testStart":
            test = event.get("test") or {}
            suite = test.get("suiteID")
            test_suite[test.get("id")] = suite
            first.setdefault(suite, at / 1000)
        elif kind == "testDone":
            suite = test_suite.get(event.get("testID"))
            if suite is not None:
                last[suite] = at / 1000
    spans = {}
    for suite, path in paths.items():
        if suite in first:
            spans[path] = max(last.get(suite, first[suite]) - first[suite], 0.0)
    return spans, wall


def file_costs(spans, wall):
    """{file: seconds} adding up to the run's wall time: each file's span
    plus an even share of the time between files (the runner collecting
    coverage and starting the next), scaled down when files overlapped."""
    if not spans:
        return {}
    between = max(wall - sum(spans.values()), 0.0) / len(spans)
    costs = {f: s + between for f, s in spans.items()}
    total = sum(costs.values())
    scale = wall / total if total > wall > 0 else 1.0
    return {f: c * scale for f, c in costs.items()}


def run_times(folder):
    """{package: {file: seconds}} from a run's artifacts
    (folder/coverage-<package>-<shard>/tests.jsonl)."""
    result = {}
    for package in PACKAGES:
        files = {}
        for report in sorted(glob.glob(os.path.join(folder, f"coverage-{package}-*", "tests.jsonl"))):
            with open(report) as f:
                for name, seconds in file_costs(*report_times(f, package)).items():
                    files[name] = max(seconds, files.get(name, 0.0))
        if files:
            result[package] = {k: round(v, 2) for k, v in sorted(files.items())}
    return result


def read_times(path, package):
    """{file: seconds} for package from a times file; {} when there is
    none or it can't be read (the split then uses bytes). The file comes
    from another run's artifact: only sane names and numbers count."""
    if not path or not os.path.exists(path):
        return {}
    try:
        with open(path) as f:
            entry = json.load(f).get(package) or {}
        return {str(k): float(v) for k, v in entry.items()
                if re.fullmatch(r"test/[\w/.-]+_test\.dart", str(k)) and 0 <= float(v) < 3600}
    except (ValueError, TypeError, AttributeError, OSError):
        return {}


def weights(package, times_path=None):
    """({file: weight}, estimated seconds of one job running them all)."""
    files = test_files(package)
    name = os.path.basename(os.path.normpath(package))
    measured = read_times(times_path, name)
    known = {f: measured[f] for f in files if f in measured}
    if known:
        usual = statistics.median(known.values())
        result = {f: max(known.get(f, usual), 0.01) for f in files}
        return result, sum(result.values())
    sizes = {f: max(os.path.getsize(os.path.join(package, f)), 1) for f in files}
    rate = SECONDS_PER_KB.get(name, DEFAULT_SECONDS_PER_KB)
    return sizes, sum(sizes.values()) / 1000 * rate


def shard_count(seconds, files, target=TARGET_SECONDS, most=MAX_SHARDS):
    """Enough shards for about `target` seconds each, from 1 to `most`,
    never more than `files`."""
    return max(1, min(math.ceil(seconds / target), most, files))


def plan(package, times_path=None):
    """check.yml's matrix: [{"shard": i, "files": "test/a.dart ..."}]."""
    found, seconds = weights(package, times_path)
    groups = shards(found, shard_count(seconds, len(found)))
    return [{"shard": i, "files": " ".join(g)} for i, g in enumerate(groups)]


def _usage():
    print("Usage: test_shard.py plan <package> [times.json]\n"
          "       test_shard.py <package> <shards> <index> [times.json]\n"
          "       test_shard.py times <folder>", file=sys.stderr)
    return 64


def main(argv):
    if argv[:1] == ["times"]:
        if len(argv) != 2:
            return _usage()
        print(json.dumps(run_times(argv[1]), indent=1, sort_keys=True))
        return 0
    if argv[:1] == ["plan"]:
        if len(argv) not in (2, 3):
            return _usage()
        if not test_files(argv[1]):
            print(f"No *_test.dart under {argv[1]}/test.", file=sys.stderr)
            return 1
        print(json.dumps(plan(*argv[1:])))
        return 0
    if len(argv) not in (3, 4):
        return _usage()
    package = argv[0]
    try:
        total, index = int(argv[1]), int(argv[2])
    except ValueError:
        return _usage()
    if total < 1 or not 0 <= index < total:
        print(f"Shard {index} of {total} does not exist.", file=sys.stderr)
        return 64
    found, _ = weights(package, argv[3] if len(argv) == 4 else None)
    if not found:
        print(f"No *_test.dart under {package}/test.", file=sys.stderr)
        return 1
    chosen = shards(found, total)[index]
    if not chosen:
        # The runner given no file runs every test: say so instead.
        print(f"Shard {index} of {total} has no test file (fewer shards).", file=sys.stderr)
        return 1
    print(" ".join(chosen))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
